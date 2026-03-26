with Sf.Graphics.RenderWindow;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;

with Sf.Window.Event;
with Sf.Window.Mouse;

with Sf.System.Vector2;

with Ada.Containers.Vectors;
with Ada.Numerics.Float_Random;

procedure Netwalk is

   use type Sf.Window.Event.sfEventType;
   use type Sf.Window.Mouse.sfMouseButton;

   use Sf.Graphics;
   use Sf.Window;
   use Sf.System;
   use Sf;

   N             : constant Integer := 6;
   Tile_Size     : constant sfInt32 := 54;
   Tile_Size_Int : constant Integer := Integer (Tile_Size);
   Offset_F      : constant Vector2.sfVector2f := (x => 65.0, y => 55.0);
   Offset_I      : constant Vector2.sfVector2i := (x => 65, y => 55);

   subtype Grid_Index is Integer range 0 .. N - 1;

   type Position is record
      x : Integer := 0;
      y : Integer := 0;
   end record;

   function "+" (Left, Right : Position) return Position is
   begin
      return (x => Left.x + Right.x, y => Left.y + Right.y);
   end "+";

   function "-" (Value : Position) return Position is
   begin
      return (x => -Value.x, y => -Value.y);
   end "-";

   function Equal (Left, Right : Position) return Boolean is
   begin
      return Left.x = Right.x and then Left.y = Right.y;
   end Equal;

   Up    : constant Position := (x => 0, y => -1);
   Right : constant Position := (x => 1, y => 0);
   Down  : constant Position := (x => 0, y => 1);
   Left  : constant Position := (x => -1, y => 0);

   subtype Dir_Index is Positive range 1 .. 4;
   type Dir_Array is array (Dir_Index) of Position;
   Directions : constant Dir_Array :=
     (1 => Up, 2 => Right, 3 => Down, 4 => Left);

   package Direction_Vectors is new
     Ada.Containers.Vectors (Index_Type => Natural, Element_Type => Position);

   type Pipe is record
      dirs        : Direction_Vectors.Vector := Direction_Vectors.Empty_Vector;
      orientation : Integer := 0;
      angle       : Float := 0.0;
      on          : Boolean := False;
   end record;

   function Empty_Pipe return Pipe is
   begin
      return
        (dirs        => Direction_Vectors.Empty_Vector,
         orientation => 0,
         angle       => 0.0,
         on          => False);
   end Empty_Pipe;

   type Grid_Array is array (Grid_Index, Grid_Index) of Pipe;
   grid : Grid_Array := (others => (others => Empty_Pipe));

   package Node_Vectors is new
     Ada.Containers.Vectors (Index_Type => Natural, Element_Type => Position);

   package Random_Float renames Ada.Numerics.Float_Random;
   Rand_Gen : Random_Float.Generator;

   app : constant sfRenderWindow_Ptr :=
     RenderWindow.create ((390, 390, 32), "The Pipe Puzzle!");
   e   : Event.sfEvent;

   background_Texture : constant sfTexture_Ptr :=
     Texture.createFromFile ("images/background.png");
   comp_Texture       : constant sfTexture_Ptr :=
     Texture.createFromFile ("images/comp.png");
   server_Texture     : constant sfTexture_Ptr :=
     Texture.createFromFile ("images/server.png");
   pipes_Texture      : constant sfTexture_Ptr :=
     Texture.createFromFile ("images/pipes.png");

   background_Sprite : constant sfSprite_Ptr := Sprite.create;
   comp_Sprite       : constant sfSprite_Ptr := Sprite.create;
   server_Sprite     : constant sfSprite_Ptr := Sprite.create;
   pipe_Sprite       : constant sfSprite_Ptr := Sprite.create;

   function Random_Bound (Bound : Positive) return Integer is
      Value  : constant Float := Random_Float.Random (Rand_Gen);
      Result : Integer := Integer (Float (Bound) * Value);
   begin
      if Result >= Bound then
         Result := Bound - 1;
      end if;
      return Result;
   end Random_Bound;

   function Random_Cell return Position is
   begin
      return (x => Random_Bound (N), y => Random_Bound (N));
   end Random_Cell;

   function Is_Out (Pos : Position) return Boolean is
   begin
      return
        Pos.x < Grid_Index'First
        or else Pos.x > Grid_Index'Last
        or else Pos.y < Grid_Index'First
        or else Pos.y > Grid_Index'Last;
   end Is_Out;

   function Connection_Count (P : Pipe) return Natural is
   begin
      return Natural (P.dirs.Length);
   end Connection_Count;

   function Is_Connect (P : Pipe; Dir : Position) return Boolean is
   begin
      for Cursor in P.dirs.Iterate loop
         if Equal (Direction_Vectors.Element (Cursor), Dir) then
            return True;
         end if;
      end loop;
      return False;
   end Is_Connect;

   procedure Rotate (P : in out Pipe) is
   begin
      for Cursor in P.dirs.Iterate loop
         declare
            Dir      : constant Position := Direction_Vectors.Element (Cursor);
            Next_Dir : Position;
         begin
            if Equal (Dir, Up) then
               Next_Dir := Right;
            elsif Equal (Dir, Right) then
               Next_Dir := Down;
            elsif Equal (Dir, Down) then
               Next_Dir := Left;
            else
               Next_Dir := Up;
            end if;
            P.dirs.Replace_Element (Cursor, Next_Dir);
         end;
      end loop;
   end Rotate;

   procedure Clear_Grid is
   begin
      for Row in Grid_Index loop
         for Col in Grid_Index loop
            grid (Col, Row).dirs.Clear;
            grid (Col, Row).orientation := 0;
            grid (Col, Row).angle := 0.0;
            grid (Col, Row).on := False;
         end loop;
      end loop;
   end Clear_Grid;

   procedure Reset_On_Flags is
   begin
      for Row in Grid_Index loop
         for Col in Grid_Index loop
            grid (Col, Row).on := False;
         end loop;
      end loop;
   end Reset_On_Flags;

   procedure Drop (Pos : Position) is
   begin
      if Is_Out (Pos) then
         return;
      end if;

      declare
         Col  : constant Grid_Index := Grid_Index (Pos.x);
         Row  : constant Grid_Index := Grid_Index (Pos.y);
         Curr : Pipe renames grid (Col, Row);
      begin
         if Curr.on then
            return;
         end if;

         Curr.on := True;

         for Dir_Pos in Dir_Index loop
            declare
               Dir : constant Position := Directions (Dir_Pos);
            begin
               if Is_Connect (Curr, Dir) then
                  declare
                     Next_Pos : constant Position := Pos + Dir;
                  begin
                     if not Is_Out (Next_Pos) then
                        declare
                           Next_Col : constant Grid_Index :=
                             Grid_Index (Next_Pos.x);
                           Next_Row : constant Grid_Index :=
                             Grid_Index (Next_Pos.y);
                           Neighbor : Pipe renames grid (Next_Col, Next_Row);
                        begin
                           if Is_Connect (Neighbor, -Dir) then
                              Drop (Next_Pos);
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
      end;
   end Drop;

   procedure Generate_Puzzle is
      use Node_Vectors;
      Nodes : Vector;
   begin
      Clear_Grid;
      Nodes.Append (Random_Cell);

      while not Nodes.Is_Empty loop
         declare
            Node_Index : constant Natural :=
              Random_Bound (Integer (Nodes.Length));
            V          : constant Position :=
              Nodes.Element (Index => Node_Index);
            Curr       : Pipe renames
              grid (Grid_Index (V.x), Grid_Index (V.y));
            Curr_Count : constant Natural := Connection_Count (Curr);
         begin
            if Curr_Count = 3 then
               Nodes.Delete (Node_Index);
            elsif Curr_Count = 2 and then Random_Bound (50) /= 0 then
               null;
            else
               declare
                  Complete : Boolean := True;
               begin
                  for Dir_Pos in Dir_Index loop
                     declare
                        Dir      : constant Position := Directions (Dir_Pos);
                        Next_Pos : constant Position := V + Dir;
                     begin
                        if not Is_Out (Next_Pos) then
                           declare
                              Neighbor : Pipe renames
                                grid
                                  (Grid_Index (Next_Pos.x),
                                   Grid_Index (Next_Pos.y));
                           begin
                              if Connection_Count (Neighbor) = 0 then
                                 Complete := False;
                              end if;
                           end;
                        end if;
                     end;
                  end loop;

                  if Complete then
                     Nodes.Delete (Node_Index);
                  else
                     declare
                        Dir_Choice : constant Position :=
                          Directions (Random_Bound (4) + 1);
                        Next_Pos   : constant Position := V + Dir_Choice;
                     begin
                        if not Is_Out (Next_Pos) then
                           declare
                              Neighbor : Pipe renames
                                grid
                                  (Grid_Index (Next_Pos.x),
                                   Grid_Index (Next_Pos.y));
                           begin
                              if Connection_Count (Neighbor) = 0 then
                                 Curr.dirs.Append (Dir_Choice);
                                 Neighbor.dirs.Append (-Dir_Choice);
                                 Nodes.Append (Next_Pos);
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Generate_Puzzle;

   function Get_Kind (P : Pipe) return Integer is
      Count : constant Integer := Integer (P.dirs.Length);
   begin
      if Count = 2 then
         declare
            First_Index : constant Natural := P.dirs.First_Index;
            Last_Index  : constant Natural := P.dirs.Last_Index;
            First_Dir   : constant Position :=
              Direction_Vectors.Element (P.dirs, Index => First_Index);
            Second_Dir  : constant Position :=
              Direction_Vectors.Element (P.dirs, Index => Last_Index);
         begin
            if Equal (First_Dir, -Second_Dir) then
               return 0;
            end if;
         end;
      end if;
      return Count;
   end Get_Kind;

   Server_Pos : Position := (0, 0);

begin

   Random_Float.Reset (Rand_Gen);

   RenderWindow.setFramerateLimit (app, 60);

   Sprite.setTexture (background_Sprite, background_Texture);
   Sprite.setTexture (comp_Sprite, comp_Texture);
   Sprite.setTexture (server_Sprite, server_Texture);
   Sprite.setTexture (pipe_Sprite, pipes_Texture);

   Sprite.setOrigin (pipe_Sprite, (27.0, 27.0));
   Sprite.setOrigin (comp_Sprite, (18.0, 18.0));
   Sprite.setOrigin (server_Sprite, (20.0, 20.0));
   Texture.setSmooth (pipes_Texture, sfTrue);

   Generate_Puzzle;

   for Row in Grid_Index loop
      for Col in Grid_Index loop
         declare
            Cell : Pipe renames grid (Col, Row);
         begin
            for N in reverse Dir_Index loop
               declare
                  Pattern : String (1 .. 4);
                  Index   : Positive := 1;
               begin
                  for Dir_Pos in Dir_Index loop
                     if Is_Connect (Cell, Directions (Dir_Pos)) then
                        Pattern (Index) := '1';
                     else
                        Pattern (Index) := '0';
                     end if;
                     Index := Index + 1;
                  end loop;

                  if Pattern = "0011"
                    or else Pattern = "0111"
                    or else Pattern = "0101"
                    or else Pattern = "0010"
                  then
                     Cell.orientation := Integer (N);
                  end if;

                  Rotate (Cell);
               end;
            end loop;

            declare
               Rotations : constant Integer := Random_Bound (4);
            begin
               for Turn in 1 .. Rotations loop
                  Cell.orientation := Cell.orientation + 1;
                  Rotate (Cell);
               end loop;
            end;
         end;
      end loop;
   end loop;

   loop
      Server_Pos := Random_Cell;
      exit when
        Connection_Count
          (grid (Grid_Index (Server_Pos.x), Grid_Index (Server_Pos.y)))
        /= 1;
   end loop;

   Sprite.setPosition
     (server_Sprite,
      (Float (Server_Pos.x * Tile_Size_Int),
       Float (Server_Pos.y * Tile_Size_Int)));
   Sprite.move (server_Sprite, Offset_F);

   while RenderWindow.isOpen (app) = sfTrue loop

      while RenderWindow.PollEvent (app, event => e) = sfTrue loop
         case e.eventType is
            when Event.sfEvtClosed             =>
               RenderWindow.close (app);

            when Event.sfEvtMouseButtonPressed =>
               if e.mouseButton.button = Mouse.sfMouseLeft then
                  declare
                     mouse_Pos : constant Vector2.sfVector2i :=
                       RenderWindow.Mouse.getPosition (app);
                     mouse_x   : constant Integer := Integer (mouse_Pos.x);
                     mouse_y   : constant Integer := Integer (mouse_Pos.y);
                     Offset_X  : constant Integer := Integer (Offset_I.x);
                     Offset_Y  : constant Integer := Integer (Offset_I.y);
                     local_x   : constant Integer :=
                       (mouse_x + Tile_Size_Int / 2 - Offset_X)
                       / Tile_Size_Int;
                     local_y   : constant Integer :=
                       (mouse_y + Tile_Size_Int / 2 - Offset_Y)
                       / Tile_Size_Int;
                     local_Pos : constant Position :=
                       (x => local_x, y => local_y);
                  begin
                     if not Is_Out (local_Pos) then
                        declare
                           Cell : Pipe renames
                             grid
                               (Grid_Index (local_Pos.x),
                                Grid_Index (local_Pos.y));
                        begin
                           Cell.orientation := Cell.orientation + 1;
                           Rotate (Cell);
                        end;
                     end if;
                  end;
               end if;

            when others                        =>
               null;
         end case;
      end loop;

      Reset_On_Flags;
      Drop (Server_Pos);

      RenderWindow.clear (app);
      RenderWindow.drawSprite (app, background_Sprite);

      for Row in Grid_Index loop
         for Col in Grid_Index loop
            declare
               P          : Pipe renames grid (Col, Row);
               Kind       : constant Integer := Get_Kind (P);
               Target     : constant Float := Float (P.orientation) * 90.0;
               Position_F : constant Vector2.sfVector2f :=
                 (Float (Col * Tile_Size_Int), Float (Row * Tile_Size_Int));
            begin
               P.angle := P.angle + 5.0;
               if P.angle > Target then
                  P.angle := Target;
               end if;

               Sprite.setTextureRect
                 (pipe_Sprite,
                  (Kind * Tile_Size_Int, 0, Tile_Size_Int, Tile_Size_Int));
               Sprite.setRotation (pipe_Sprite, P.angle);
               Sprite.setPosition (pipe_Sprite, Position_F);
               Sprite.move (pipe_Sprite, Offset_F);
               RenderWindow.drawSprite (app, pipe_Sprite);

               if Connection_Count (P) = 1 then
                  if P.on then
                     Sprite.setTextureRect (comp_Sprite, (53, 0, 36, 36));
                  else
                     Sprite.setTextureRect (comp_Sprite, (0, 0, 36, 36));
                  end if;
                  Sprite.setPosition (comp_Sprite, Position_F);
                  Sprite.move (comp_Sprite, Offset_F);
                  RenderWindow.drawSprite (app, comp_Sprite);
               end if;
            end;
         end loop;
      end loop;

      RenderWindow.drawSprite (app, server_Sprite);
      RenderWindow.display (app);

   end loop;

   Sprite.destroy (background_Sprite);
   Sprite.destroy (comp_Sprite);
   Sprite.destroy (server_Sprite);
   Sprite.destroy (pipe_Sprite);

   Texture.destroy (background_Texture);
   Texture.destroy (comp_Texture);
   Texture.destroy (server_Texture);
   Texture.destroy (pipes_Texture);

   RenderWindow.destroy (app);

end Netwalk;
