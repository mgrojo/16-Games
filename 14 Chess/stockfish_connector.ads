package Stockfish_Connector is

   procedure Connect (Path : String := "");
   --  Configure the Stockfish executable path and ensure that an engine
   --  process spawned via GNAT.Expect is running. If Path is empty, the
   --  package will look for the STOCKFISH_PATH environment variable or fall
   --  back to "stockfish" on the current PATH.

   function Next_Move (Moves : String) return String;
   --  Request the next move from Stockfish given the list of moves in UCI
   --  format separated by spaces. Returns a 4-character move such as "e2e4",
   --  or an empty string if no move could be produced.

   procedure Close;
   --  Terminate the background Stockfish process, if any.

end Stockfish_Connector;
