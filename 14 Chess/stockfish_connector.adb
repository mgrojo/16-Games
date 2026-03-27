with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNAT.Expect;
with GNAT.OS_Lib;
with GNAT.Regpat;

package body Stockfish_Connector is

   use type GNAT.OS_Lib.String_Access;
   use type GNAT.Expect.Expect_Match;

   Engine_Path : Unbounded_String := To_Unbounded_String ("stockfish");
   Engine      : GNAT.Expect.Process_Descriptor;
   Engine_Up   : Boolean := False;

   Bestmove_Pattern : constant String := "bestmove ([a-h][1-8][a-h][1-8])";
   Command_Timeout  : constant Integer := 3_000;

   procedure Free_Args (Args : in out GNAT.OS_Lib.Argument_List) is
   begin
      for Item of Args loop
         if Item /= null then
            GNAT.OS_Lib.Free (Item);
            Item := null;
         end if;
      end loop;
   end Free_Args;

   procedure Drain_Output (Timeout : Integer := 0) is
   begin
      if Engine_Up then
         GNAT.Expect.Flush (Engine, Timeout);
      end if;
   exception
      when others =>
         null;
   end Drain_Output;

   procedure Shutdown is
      Status : Integer;
   begin
      if not Engine_Up then
         return;
      end if;

      begin
         GNAT.Expect.Send (Engine, "quit");
      exception
         when others =>
            null;
      end;

      begin
         GNAT.Expect.Close (Engine, Status);
      exception
         when others =>
            null;
      end;

      Engine_Up := False;
   end Shutdown;

   function Spawn_Engine return Boolean is
      Args : GNAT.OS_Lib.Argument_List (1 .. 2) := (others => null);
   begin
      if Engine_Up then
         return True;
      end if;

      Args (1) := new String'("-c");
      Args (2) := new String'(To_String (Engine_Path));
      GNAT.Expect.Non_Blocking_Spawn
        (Descriptor  => Engine,
         Command     => "/bin/sh",
         Args        => Args,
         Buffer_Size => 16_384,
         Err_To_Out  => True);
      Free_Args (Args);

      Engine_Up := True;
      Drain_Output (Timeout => 0);
      return True;
   exception
      when GNAT.Expect.Invalid_Process =>
         Free_Args (Args);
         Engine_Up := False;
         return False;
      when others =>
         Free_Args (Args);
         Engine_Up := False;
         return False;
   end Spawn_Engine;

   function Ensure_Engine return Boolean is
   begin
      if Engine_Up then
         return True;
      end if;

      return Spawn_Engine;
   end Ensure_Engine;

   procedure Apply_Path (Path : String) is
      Env_Path : constant String := Ada.Environment_Variables.Value ("STOCKFISH_PATH", "");
      Desired  : constant String :=
        (if Path'Length > 0 then Path
         elsif Env_Path'Length > 0 then Env_Path
         else To_String (Engine_Path));
   begin
      if Desired'Length > 0 and then Desired /= To_String (Engine_Path) then
         Engine_Path := To_Unbounded_String (Desired);
         Shutdown;
      elsif Desired'Length = 0 then
         null;
      else
         Engine_Path := To_Unbounded_String (Desired);
      end if;
   end Apply_Path;

   function Build_Position_Command (Moves : String) return String is
   begin
      if Moves'Length = 0 then
         return "position startpos";
      else
         return "position startpos moves " & Moves;
      end if;
   end Build_Position_Command;

   function Extract_Bestmove return String is
      Matches : GNAT.Regpat.Match_Array (0 .. 1);
      Result  : GNAT.Expect.Expect_Match;
   begin
      GNAT.Expect.Expect
        (Descriptor => Engine,
         Result     => Result,
         Regexp     => Bestmove_Pattern,
         Matched    => Matches,
         Timeout    => Command_Timeout);

      if Result >= 1
        and then Matches (1).First /= 0
        and then Matches (1).Last >= Matches (1).First
      then
         declare
            Output : constant String := GNAT.Expect.Expect_Out (Engine);
            First  : constant Natural := Matches (1).First;
            Last   : constant Natural := Matches (1).Last;
         begin
            if First >= Output'First and then Last <= Output'Last then
               return Output (First .. Last);
            end if;
         end;
      end if;

      return "";
   exception
      when GNAT.Expect.Process_Died =>
         Engine_Up := False;
         return "";
      when GNAT.Expect.Invalid_Process =>
         Engine_Up := False;
         return "";
      when others =>
         return "";
   end Extract_Bestmove;

   procedure Connect (Path : String := "") is
   begin
      Apply_Path (Path);
      declare
         Success : constant Boolean := Ensure_Engine;
         pragma Unreferenced (Success);
      begin
         null;
      end;
   end Connect;

   function Next_Move (Moves : String) return String is
   begin
      if not Ensure_Engine then
         return "";
      end if;

      begin
         GNAT.Expect.Send
           (Descriptor   => Engine,
            Str          => Build_Position_Command (Moves),
            Add_LF       => True,
            Empty_Buffer => True);
         GNAT.Expect.Send (Engine, "go depth 3");
      exception
         when GNAT.Expect.Process_Died =>
            Engine_Up := False;
            return "";
         when GNAT.Expect.Invalid_Process =>
            Engine_Up := False;
            return "";
      end;

      return Extract_Bestmove;
   end Next_Move;

   procedure Close is
   begin
      Shutdown;
   end Close;

end Stockfish_Connector;
