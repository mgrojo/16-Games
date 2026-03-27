with Sf.Graphics.RenderWindow;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.Rect; use Sf.Graphics.Rect;
with Sf.System.Vector2;

with Sf.Window.Event;
with Sf.Window.Keyboard;
with Sf.Window.Mouse;
with Sf;

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Stockfish_Connector;

procedure Chess is

   use Sf.Graphics;
   use Sf.System;
   use Sf.Window;
   use Sf.Window.Event;
   use Sf.Window.Mouse;
   use Sf;
   use Ada.Strings.Unbounded;
   use type Sf.Window.Keyboard.sfKeyCode;
   use type Sf.Window.Mouse.sfMouseButton;

   Size     : constant sfInt32 := 56;
   Size_Int : constant Integer := Integer (Size);
   Size_F32 : constant Float := Float (Size_Int);
    Offset   : constant Vector2.sfVector2f :=
       (x => Size_F32 / 2.0, y => Size_F32 / 2.0);

   type Board_Row is array (Integer range 0 .. 7) of Integer;
   type Board_Array is array (Integer range 0 .. 7) of Board_Row;

   Initial_Board : constant Board_Array :=
     ((-1, -2, -3, -4, -5, -3, -2, -1),
      (-6, -6, -6, -6, -6, -6, -6, -6),
      (0, 0, 0, 0, 0, 0, 0, 0),
      (0, 0, 0, 0, 0, 0, 0, 0),
      (0, 0, 0, 0, 0, 0, 0, 0),
      (0, 0, 0, 0, 0, 0, 0, 0),
      (6, 6, 6, 6, 6, 6, 6, 6),
      (1, 2, 3, 4, 5, 3, 2, 1));

   subtype Piece_Index is Integer range 0 .. 31;

   type Move_String is new String (1 .. 4);

   package Move_Vectors is new Ada.Containers.Vectors (Positive, Move_String);
   Moves : Move_Vectors.Vector;

   Figures_Texture : sfTexture_Ptr := null;
   Board_Texture   : sfTexture_Ptr := null;
   Board_Sprite    : constant sfSprite_Ptr  := Sprite.create;
   Figures         : constant array (Piece_Index) of sfSprite_Ptr := (others => Sprite.create);

   function Same_Position (Left, Right : Vector2.sfVector2f) return Boolean is
      Tolerance : constant Float := 0.5;
   begin
      return abs (Left.x - Right.x) <= Tolerance
        and then abs (Left.y - Right.y) <= Tolerance;
   end Same_Position;

   function To_Chess_Note (P : Vector2.sfVector2f) return String is
   File_Index : constant Integer := Integer (Float'Floor (P.x / Size_F32));
   Rank_Index : constant Integer := Integer (Float'Floor (P.y / Size_F32));
         File_Char  : constant Character :=
            Character'Val (Character'Pos ('a') + File_Index);
         Rank_Char  : constant Character :=
            Character'Val (Character'Pos ('8') - Rank_Index);
   begin
      return String'(1 => File_Char, 2 => Rank_Char);
   end To_Chess_Note;

   function To_Coord (File_Char, Rank_Char : Character) return Vector2.sfVector2f is
      File_Index : constant Integer := Character'Pos (File_Char) - Character'Pos ('a');
      Rank_Index : constant Integer := Character'Pos ('8') - Character'Pos (Rank_Char);
   begin
      return (x => Float (Size_Int * File_Index), y => Float (Size_Int * Rank_Index));
   end To_Coord;

   function To_Move (Value : String) return Move_String is
      Result : Move_String := (others => ' ');
   begin
      if Value'Length = 4 then
         Result := Move_String (Value);
      end if;
      return Result;
   end To_Move;

   function Moves_As_String return String is
      Result    : Unbounded_String;
      Is_First  : Boolean := True;
   begin
      if Moves.Is_Empty then
         return "";
      end if;

      declare
         First_Index : constant Positive := Moves.First_Index;
         Last_Index  : constant Positive := Moves.Last_Index;
      begin
         for Index in First_Index .. Last_Index loop
            if not Is_First then
               Append (Result, ' ');
            else
               Is_First := False;
            end if;
            Append (Result, String (Moves.Element (Index)));
         end loop;
      end;

      return To_String (Result);
   end Moves_As_String;

   function Square_Was_Source (Square : String; History_Count : Natural) return Boolean is
      Limit : constant Natural := Natural'Min
        (History_Count, Natural (Moves.Length));
   begin
      if Limit = 0 or else Moves.Is_Empty then
         return False;
      end if;

      declare
         First_Index : constant Positive := Moves.First_Index;
      begin
         for Offset in 0 .. Limit - 1 loop
            declare
               Current_Index : constant Positive := Positive (First_Index + Offset);
               Move_Text     : constant String := String (Moves.Element (Current_Index));
               Origin        : constant String :=
                 Move_Text (Move_Text'First .. Move_Text'First + 1);
            begin
               if Origin = Square then
                  return True;
               end if;
            end;
         end loop;
      end;

      return False;
   end Square_Was_Source;

   procedure Move_Pieces (Move_Text : String; History_Count : Natural);

   procedure Reset_Figures is
      Next_Index : Integer := Figures'First;
   begin
      for Row in Initial_Board'Range loop
         for Col in Initial_Board (Row)'Range loop
            declare
               Value : constant Integer := Initial_Board (Row)(Col);
            begin
               if Value /= 0 then
                  declare
                     Piece    : constant Piece_Index := Piece_Index (Next_Index);
                     TextureX : constant Integer := abs (Value) - 1;
                     TextureY : constant Integer := (if Value > 0 then 1 else 0);
                  begin
                     Sprite.setTexture (Figures (Piece), Figures_Texture);
                                                Sprite.setTextureRect
                                                    (Figures (Piece),
                                                       (Size_Int * TextureX,
                                                         Size_Int * TextureY,
                                                         Size_Int,
                                                         Size_Int));
                     Sprite.setPosition
                       (Figures (Piece),
                                    (Float (Size_Int * Col), Float (Size_Int * Row)));
                     Next_Index := Next_Index + 1;
                  end;
               end if;
            end;
         end loop;
      end loop;

      if Next_Index <= Figures'Last then
         for Piece in Piece_Index range Piece_Index (Next_Index) .. Figures'Last loop
            Sprite.setPosition (Figures (Piece), (-100.0, -100.0));
         end loop;
      end if;
   end Reset_Figures;

   procedure Move_Pieces (Move_Text : String; History_Count : Natural) is
      Old_Pos : constant Vector2.sfVector2f :=
        To_Coord (Move_Text (Move_Text'First),
                  Move_Text (Move_Text'First + 1));
      New_Pos : constant Vector2.sfVector2f :=
        To_Coord (Move_Text (Move_Text'First + 2),
                  Move_Text (Move_Text'First + 3));
   begin
      for Piece in Figures'Range loop
         if Same_Position (Sprite.getPosition (Figures (Piece)), New_Pos) then
            Sprite.setPosition (Figures (Piece), (-100.0, -100.0));
         end if;
      end loop;

      for Piece in Figures'Range loop
         if Same_Position (Sprite.getPosition (Figures (Piece)), Old_Pos) then
            Sprite.setPosition (Figures (Piece), New_Pos);
         end if;
      end loop;

   if Move_Text = "e1g1" and then not Square_Was_Source ("e1", History_Count) then
         Move_Pieces ("h1f1", History_Count);
      elsif Move_Text = "e8g8" and then not Square_Was_Source ("e8", History_Count) then
         Move_Pieces ("h8f8", History_Count);
      elsif Move_Text = "e1c1" and then not Square_Was_Source ("e1", History_Count) then
         Move_Pieces ("a1d1", History_Count);
      elsif Move_Text = "e8c8" and then not Square_Was_Source ("e8", History_Count) then
         Move_Pieces ("a8d8", History_Count);
      end if;
   end Move_Pieces;

   procedure Load_Position is
      Applied : Natural := 0;
   begin
      Reset_Figures;
      if Moves.Is_Empty then
         return;
      end if;

      declare
         First_Index : constant Positive := Moves.First_Index;
         Last_Index  : constant Positive := Moves.Last_Index;
      begin
         for Index in First_Index .. Last_Index loop
            Move_Pieces (String (Moves.Element (Index)), Applied);
            Applied := Applied + 1;
         end loop;
      end;
   end Load_Position;

    function Contains (Bounds : sfFloatRect; Point : Vector2.sfVector2f)
       return Boolean is
         Local_Bounds : aliased constant sfFloatRect := Bounds;
    begin
         return Rect.contains (Local_Bounds'Access, Point.x, Point.y) = sfTrue;
    end Contains;

   App : constant sfRenderWindow_Ptr :=
     RenderWindow.create ((504, 504, 32), "The Chess! (press SPACE)");

   Evt : sfEvent;

   Is_Move        : Boolean := False;
   Selected_Index : Piece_Index := Piece_Index'First;
   Drag_Delta     : Vector2.sfVector2f := (0.0, 0.0);
   Old_Pos        : Vector2.sfVector2f := (0.0, 0.0);
   New_Pos        : Vector2.sfVector2f := (0.0, 0.0);
   Pos            : Vector2.sfVector2f := (0.0, 0.0);
   Space_Was_Pressed : Boolean := False;

begin

   Figures_Texture := Texture.createFromFile ("images/figures.png");
   Board_Texture   := Texture.createFromFile ("images/board.png");

   Sprite.setTexture (Board_Sprite, Board_Texture);

   for Piece in Figures'Range loop
      Sprite.setTexture (Figures (Piece), Figures_Texture);
   end loop;

   Reset_Figures;

   Stockfish_Connector.Connect;

   while RenderWindow.isOpen (App) = sfTrue loop

      declare
         Mouse_Pos : constant Vector2.sfVector2i :=
           RenderWindow.Mouse.getPosition (App);
      begin
         Pos := (Float (Mouse_Pos.x) - Offset.x, Float (Mouse_Pos.y) - Offset.y);
      end;

      while RenderWindow.PollEvent (App, event => Evt) = sfTrue loop
         case Evt.eventType is
            when Event.sfEvtClosed =>
               RenderWindow.close (App);

            when Event.sfEvtKeyPressed =>
               if Evt.key.code = Keyboard.sfKeyBackSpace then
                  if not Moves.Is_Empty then
                     Moves.Delete_Last;
                     Load_Position;
                  end if;
               end if;

            when Event.sfEvtMouseButtonPressed =>
               if Evt.mouseButton.button = Mouse.sfMouseLeft then
                  for Piece in Figures'Range loop
                     declare
                        Bounds : constant sfFloatRect :=
                          Sprite.getGlobalBounds (Figures (Piece));
                     begin
                        if Contains (Bounds, Pos) then
                           Is_Move        := True;
                           Selected_Index := Piece;
                           Drag_Delta     :=
                             (Pos.x - Sprite.getPosition (Figures (Piece)).x,
                              Pos.y - Sprite.getPosition (Figures (Piece)).y);
                           Old_Pos        := Sprite.getPosition (Figures (Piece));
                           exit;
                        end if;
                     end;
                  end loop;
               end if;

            when Event.sfEvtMouseButtonReleased =>
               if Evt.mouseButton.button = Mouse.sfMouseLeft and then Is_Move then
                  Is_Move := False;
                  declare
                               Current : constant Vector2.sfVector2f :=
                       Sprite.getPosition (Figures (Selected_Index));
                     Half_Size : constant Float := Size_F32 / 2.0;
                     Grid_X    : constant Integer :=
                                  Integer (Float'Floor ((Current.x + Half_Size) / Size_F32));
                     Grid_Y    : constant Integer :=
                                  Integer (Float'Floor ((Current.y + Half_Size) / Size_F32));
                  begin
                               New_Pos :=
                                  (Float (Size_Int * Grid_X), Float (Size_Int * Grid_Y));
                     declare
                        Move_Text : constant String :=
                          To_Chess_Note (Old_Pos) & To_Chess_Note (New_Pos);
                     begin
                        Move_Pieces (Move_Text, Natural (Moves.Length));
                        if not Same_Position (Old_Pos, New_Pos) then
                           Moves.Append (To_Move (Move_Text));
                        end if;
                        Sprite.setPosition (Figures (Selected_Index), New_Pos);
                     end;
                  end;
               end if;

            when others =>
               null;
         end case;
      end loop;

      declare
         Space_Is_Down : constant Boolean :=
           (Keyboard.isKeyPressed (Keyboard.sfKeySpace) = sfTrue);
      begin
         if Space_Is_Down and then not Space_Was_Pressed then
            declare
               Engine_Move : constant String := Stockfish_Connector.Next_Move (Moves_As_String);
            begin
               if Engine_Move'Length = 4 then
                  Old_Pos := To_Coord (Engine_Move (Engine_Move'First),
                                        Engine_Move (Engine_Move'First + 1));
                  New_Pos := To_Coord (Engine_Move (Engine_Move'First + 2),
                                        Engine_Move (Engine_Move'First + 3));

                  for Piece in Figures'Range loop
                     if Same_Position (Sprite.getPosition (Figures (Piece)), Old_Pos) then
                        Selected_Index := Piece;
                        exit;
                     end if;
                  end loop;

                  declare
                     Delta_X : constant Float := New_Pos.x - Old_Pos.x;
                     Delta_Y : constant Float := New_Pos.y - Old_Pos.y;
                  begin
                     for Step in 1 .. 50 loop
                        Sprite.move (Figures (Selected_Index),
                                     (Delta_X / 50.0, Delta_Y / 50.0));
                        RenderWindow.clear (App);
                        RenderWindow.drawSprite (App, Board_Sprite);
                        for Piece in Figures'Range loop
                           Sprite.move (Figures (Piece), Offset);
                        end loop;
                        for Piece in Figures'Range loop
                           RenderWindow.drawSprite (App, Figures (Piece));
                        end loop;
                        for Piece in Figures'Range loop
                           Sprite.move (Figures (Piece), (-Offset.x, -Offset.y));
                        end loop;
                        RenderWindow.display (App);
                     end loop;
                  end;

                  Move_Pieces (Engine_Move, Natural (Moves.Length));
                  Moves.Append (To_Move (Engine_Move));
                  Sprite.setPosition (Figures (Selected_Index), New_Pos);
               end if;
            end;
         end if;

         Space_Was_Pressed := Space_Is_Down;
      end;

      if Is_Move then
         Sprite.setPosition
           (Figures (Selected_Index), (Pos.x - Drag_Delta.x, Pos.y - Drag_Delta.y));
      end if;

      RenderWindow.clear (App);
      RenderWindow.drawSprite (App, Board_Sprite);
      for Piece in Figures'Range loop
         Sprite.move (Figures (Piece), Offset);
      end loop;
      for Piece in Figures'Range loop
         RenderWindow.drawSprite (App, Figures (Piece));
      end loop;
      for Piece in Figures'Range loop
         Sprite.move (Figures (Piece), (-Offset.x, -Offset.y));
      end loop;
      RenderWindow.display (App);
   end loop;

   Stockfish_Connector.Close;

   for Piece in Figures'Range loop
      Sprite.destroy (Figures (Piece));
   end loop;
   Sprite.destroy (Board_Sprite);
   if Figures_Texture /= null then
      Texture.destroy (Figures_Texture);
   end if;
   if Board_Texture /= null then
      Texture.destroy (Board_Texture);
   end if;

end Chess;
