#pragma once

#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/select.h>
#include <fcntl.h>
#include <signal.h>

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <string>

namespace
{
   pid_t enginePid = -1;
   int engineStdinFd = -1;
   int engineStdoutFd = -1;

   void closeFd(int &fd)
   {
      if (fd >= 0)
      {
         close(fd);
         fd = -1;
      }
   }

   void waitForEngineExit()
   {
      if (enginePid <= 0)
      {
         return;
      }

      int status = 0;
      pid_t result = waitpid(enginePid, &status, WNOHANG);
      if (result == 0)
      {
         kill(enginePid, SIGTERM);
         waitpid(enginePid, &status, 0);
      }
      enginePid = -1;
   }

   bool ensureWritable(int fd, const std::string &data)
   {
      const char *buffer = data.c_str();
      size_t totalWritten = 0;
      const size_t length = data.size();

      while (totalWritten < length)
      {
         ssize_t written = write(fd, buffer + totalWritten, length - totalWritten);
         if (written < 0)
         {
            if (errno == EINTR)
            {
               continue;
            }
            std::perror("write");
            return false;
         }
         totalWritten += static_cast<size_t>(written);
      }
      return true;
   }
}

void CloseConnection();

void ConnectToEngine(const char *path)
{
   CloseConnection();

   int stdinPipe[2] = {-1, -1};
   int stdoutPipe[2] = {-1, -1};

   if (pipe(stdinPipe) == -1)
   {
      std::perror("pipe");
      return;
   }

   if (pipe(stdoutPipe) == -1)
   {
      std::perror("pipe");
      closeFd(stdinPipe[0]);
      closeFd(stdinPipe[1]);
      return;
   }

   enginePid = fork();
   if (enginePid == -1)
   {
   std::perror("fork");
   closeFd(stdinPipe[0]);
   closeFd(stdinPipe[1]);
   closeFd(stdoutPipe[0]);
   closeFd(stdoutPipe[1]);
      return;
   }

   if (enginePid == 0)
   {
      dup2(stdinPipe[0], STDIN_FILENO);
      dup2(stdoutPipe[1], STDOUT_FILENO);
      dup2(stdoutPipe[1], STDERR_FILENO);

      close(stdinPipe[0]);
      close(stdinPipe[1]);
      close(stdoutPipe[0]);
      close(stdoutPipe[1]);

      execl("/bin/sh", "sh", "-c", path, static_cast<char *>(nullptr));
      std::perror("execl");
      _exit(1);
   }

   close(stdinPipe[0]);
   close(stdoutPipe[1]);

   engineStdinFd = stdinPipe[1];
   engineStdoutFd = stdoutPipe[0];

   int flags = fcntl(engineStdoutFd, F_GETFL, 0);
   if (flags != -1)
   {
      fcntl(engineStdoutFd, F_SETFL, flags | O_NONBLOCK);
   }
}

std::string getResponseFromEngine(std::string position)
{
   if (enginePid <= 0 || engineStdinFd < 0 || engineStdoutFd < 0)
   {
      return "error";
   }

   if (!ensureWritable(engineStdinFd, position))
   {
      return "error";
   }

   std::string response;
   char buffer[2048];

   while (true)
   {
      fd_set readfds;
      FD_ZERO(&readfds);
      FD_SET(engineStdoutFd, &readfds);

      timeval timeout{};
      timeout.tv_sec = 0;
      timeout.tv_usec = 500000; // 500 ms

      int ready = select(engineStdoutFd + 1, &readfds, nullptr, nullptr, &timeout);
      if (ready == -1)
      {
         if (errno == EINTR)
         {
            continue;
         }
         std::perror("select");
         break;
      }
      if (ready == 0)
      {
         break;
      }

      ssize_t bytes = read(engineStdoutFd, buffer, sizeof(buffer));
      if (bytes <= 0)
      {
         if (bytes == -1 && errno == EINTR)
         {
            continue;
         }
         break;
      }
      response.append(buffer, buffer + bytes);
      if (bytes < static_cast<ssize_t>(sizeof(buffer)))
      {
         // Give the engine another window to produce more output.
         continue;
      }
   }

   return response;
}

void CloseConnection()
{
   if (engineStdinFd >= 0)
   {
      ensureWritable(engineStdinFd, "quit\n");
   }

   closeFd(engineStdinFd);
   closeFd(engineStdoutFd);
   waitForEngineExit();
}

