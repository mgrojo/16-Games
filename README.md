# 16 Bilingual Games in Ada and C++ using SFML

16 Games originally developed in C++ and SFML library by Russian YouTuber "[FamTrinli](https://www.youtube.com/playlist?list=PLB_ibvUSN7mzUffhiay5g5GUHyJRO4DYr)".

We like the fact that most games are coded in a single file, aren't hard to grasp and are entertaining. They are a good playground to play with the SFML library and a showcase on how easy it can be to get some simple game idea working.

## Ada

In this fork, I have ported the games to Ada 2012 in order to test and showcase the binding to
SFML: [ASFML](https://github.com/mgrojo/ASFML).
The game `15 Volleyball` also depends on [Ada_Box2d](https://github.com/charlie5/Ada_Box2d).

To build the Ada versions:

- Get the dependecies as submodules: `git submodule update --init`
- Build everything at once: `gprbuild -P all_games.gpr`
- Build an individual title: enter its directory and run `gprbuild -P <game>.gpr` or open the GPR file using GNAT Studio.

## C++
[embeddedmz](https://github.com/embeddedmz/16-Games) added CMake support to ease the building process of the 16 games under Windows and other platforms (GNU/Linux distros, macOS).

"vcpkg" can be used under Windows to install the following dependencies (watch out for the triplet parameter x86/x64):
- sfml (Ubuntu: sudo apt install libsfml-dev)
- box2d (only for the game 15: Volleyball - Ubuntu: sudo apt install libsfml-dev)

Youtuber "DeveloperPaul123" made a good [video about "vcpkg"](https://www.youtube.com/watch?v=9v1HrlSFBSM) and how it can be used with CMake.
We recommend Windows users to use "vcpkg" when configuring the CMake project. This tool will automatically copy libraries DLLs in the build directories and you will be able to launch the games from Visual Studio.

When launching a game outside Visual Studio, do not forget to move asset files/directories (e.g. images folder) in the same executable directory (or launch the game from the directory in which asset files and/or directories are located via the command line interpreter 'cmd.exe').

Compilation has been tested with:
- Microsoft Visual Studio 2019 (Windows 8.1) using vcpkg and CMake 3.17.1
- GCC 9.3.0 '(Ubuntu 20.04 LTS)

Upcoming changes:
- Volleyball doesn't seem to work well on my Windows 8.1: game launches but is not playable (no players).
- Completing some games if needed (e.g. missing Game Over in Tetris and Arkanoid).
- Add Clang-format support.
- Increase code readability/quality if needed (STL algos, smart pointers, small optimizations etc...).
- Fixing bugs (if any).
- Adding small features to some games (e.g. music).
