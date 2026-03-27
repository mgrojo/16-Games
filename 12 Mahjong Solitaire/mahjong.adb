with Sf.Graphics.RenderWindow;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Window.VideoMode;
with Sf.Window.Event;
with Sf.Window.Mouse;
with Sf.System.Vector2;

with Ada.Numerics.Float_Random;
with Ada.Containers;
with Ada.Containers.Vectors;
with Ada.Text_IO;

procedure Mahjong is

   use Sf.Graphics;
   use Sf.Window;
   use Sf.System;
   use Sf;

   use type Sf.Window.Event.sfEventType;
   use type Sf.Window.Mouse.sfMouseButton;
   use type Ada.Containers.Count_Type;

   Board_Width  : constant Integer := 30;
   Board_Height : constant Integer := 18;
   Board_Layers : constant Integer := 10;

   Tile_Width  : constant Integer := 48;
   Tile_Height : constant Integer := 66;

   Step_X : constant Integer := Tile_Width / 2 - 2;
   Step_Y : constant Integer := Tile_Height / 2 - 2;

   Offset_X : constant Float := 4.6;
   Offset_Y : constant Float := 7.1;

   Desk_Offset_X : constant Integer := 30;

   Field_Size : constant Integer := 50;
   Margin     : constant Integer := 2;

   type Vector3i is record
      x : Integer := 0;
      y : Integer := 0;
      z : Integer := 0;
   end record;

   function "=" (Left, Right : Vector3i) return Boolean is
   begin
      return
        Left.x = Right.x and then Left.y = Right.y and then Left.z = Right.z;
   end "=";

   subtype Field_Index is Integer range 0 .. Field_Size - 1;
   type Field_Array is
     array (Field_Index, Field_Index, Field_Index) of Integer;

   Field : Field_Array := (others => (others => (others => 0)));

   function In_Field (X, Y, Z : Integer) return Boolean is
   begin
      return
        (X + Margin) in Field'Range (2)
        and then (Y + Margin) in Field'Range (1)
        and then Z in Field'Range (3);
   end In_Field;

   function Cell_Value (X, Y, Z : Integer) return Integer is
   begin
      if In_Field (X, Y, Z) then
         return Field (Y + Margin, X + Margin, Z);
      else
         return 0;
      end if;
   end Cell_Value;

   function Cell_Value (Pos : Vector3i) return Integer is
   begin
      return Cell_Value (Pos.x, Pos.y, Pos.z);
   end Cell_Value;

   function Floor_Int (Value : Float) return Integer is
   begin
      return Integer (Float'Floor (Value));
   end Floor_Int;

   procedure Set_Cell (X, Y, Z : Integer; Value : Integer) is
   begin
      if In_Field (X, Y, Z) then
         Field (Y + Margin, X + Margin, Z) := Value;
      end if;
   end Set_Cell;

   procedure Set_Cell (Pos : Vector3i; Value : Integer) is
   begin
      Set_Cell (Pos.x, Pos.y, Pos.z, Value);
   end Set_Cell;

   procedure Flip_Cell (Pos : Vector3i) is
      Value : constant Integer := Cell_Value (Pos);
   begin
      if Value /= 0 then
         Set_Cell (Pos, -Value);
      end if;
   end Flip_Cell;

   function Is_Open (X, Y, Z : Integer) return Boolean is
   begin
      for I in -1 .. 1 loop
         for J in -1 .. 1 loop
            if Cell_Value (X + 2, Y + I, Z) > 0
              and then Cell_Value (X - 2, Y + J, Z) > 0
            then
               return False;
            end if;
         end loop;
      end loop;

      for I in -1 .. 1 loop
         for J in -1 .. 1 loop
            if Cell_Value (X + I, Y + J, Z + 1) > 0 then
               return False;
            end if;
         end loop;
      end loop;

      return True;
   end Is_Open;

   package Vector3_Vectors is new
     Ada.Containers.Vectors (Index_Type => Natural, Element_Type => Vector3i);

   package Random_Float renames Ada.Numerics.Float_Random;
   Rand_Gen : Random_Float.Generator;

   function Random_Bound (Bound : Positive) return Natural is
      Value  : constant Float := Random_Float.Random (Rand_Gen);
      Result : Natural := Natural (Float (Bound) * Value);
   begin
      if Result >= Bound then
         Result := Bound - 1;
      end if;
      return Result;
   end Random_Bound;

   procedure Load_Map is
      use Ada.Text_IO;

      Map_File : File_Type;

      function Read_Digit return Integer is
         C : Character;
      begin
         loop
            exit when End_Of_File (Map_File);
            Get (Map_File, C);
            if C in '0' .. '9' then
               return Character'Pos (C) - Character'Pos ('0');
            end if;
         end loop;
         return 0;
      end Read_Digit;

   begin
      Open (Map_File, In_File, "files/map.txt");

      for Y in 0 .. Board_Height - 1 loop
         for X in 0 .. Board_Width - 1 loop
            declare
               Stack_Count : constant Integer := Read_Digit;
            begin
               if Stack_Count > 0 then
                  for Z in 0 .. Stack_Count - 1 loop
                     if Cell_Value (X - 1, Y - 1, Z) /= 0 then
                        Set_Cell (X - 1, Y, Z, 0);
                        Set_Cell (X, Y - 1, Z, 0);
                     else
                        Set_Cell (X, Y, Z, 1);
                     end if;
                  end loop;
               end if;
            end;
         end loop;
      end loop;

      Close (Map_File);
   end Load_Map;

   procedure Build_Pairs is
      Pair_Id : Integer := 1;
   begin
      loop
         declare
            Opens : Vector3_Vectors.Vector;
         begin
            for Z in 0 .. Board_Layers - 1 loop
               for Y in 0 .. Board_Height - 1 loop
                  for X in 0 .. Board_Width - 1 loop
                     if Cell_Value (X, Y, Z) > 0 and then Is_Open (X, Y, Z)
                     then
                        Opens.Append ((X, Y, Z));
                     end if;
                  end loop;
               end loop;
            end loop;

            exit when Opens.Length < 2;

            declare
               Count : constant Natural := Natural (Opens.Length);
               A     : constant Natural := Random_Bound (Count);
               B     : Natural := Random_Bound (Count);
            begin
               while A = B loop
                  B := Random_Bound (Count);
               end loop;

               declare
                  Current : Integer := Pair_Id;
                  Cell_A  : constant Vector3i := Opens.Element (Index => A);
                  Cell_B  : constant Vector3i := Opens.Element (Index => B);
               begin
                  Set_Cell (Cell_A, -Current);

                  if Current > 34 then
                     Current := Current + 1;
                  end if;

                  Set_Cell (Cell_B, -Current);

                  Current := Current mod 42;
                  Pair_Id := Current + 1;
               end;
            end;

         end;
      end loop;
   end Build_Pairs;

   procedure Finalize_Map is
   begin
      for Z in 0 .. Board_Layers - 1 loop
         for Y in 0 .. Board_Height - 1 loop
            for X in 0 .. Board_Width - 1 loop
               declare
                  Value : constant Integer := Cell_Value (X, Y, Z);
               begin
                  if Value /= 0 then
                     Set_Cell (X, Y, Z, -Value);
                  end if;
               end;
            end loop;
         end loop;
      end loop;
   end Finalize_Map;

   Moves : Vector3_Vectors.Vector;

   Current_Selection  : Vector3i := (0, 0, 0);
   Previous_Selection : Vector3i := (0, 0, 0);

   mode : constant VideoMode.sfVideoMode :=
     (width => 740, height => 570, bitsPerPixel => 32);

   app : constant sfRenderWindow_Ptr :=
     RenderWindow.create (mode, "Mahjong Solitaire!");

   Tiles_Texture      : constant sfTexture_Ptr :=
     Texture.createFromFile ("files/tiles.png");
   Background_Texture : constant sfTexture_Ptr :=
     Texture.createFromFile ("files/background.png");

   Tile_Sprite       : constant sfSprite_Ptr := Sprite.create;
   Background_Sprite : constant sfSprite_Ptr := Sprite.create;

   e : Event.sfEvent;

begin

   Random_Float.Reset (Rand_Gen);

   Load_Map;
   Build_Pairs;
   Finalize_Map;

   Sprite.setTexture (Tile_Sprite, Tiles_Texture);
   Sprite.setTexture (Background_Sprite, Background_Texture);

   Texture.setSmooth (Tiles_Texture, sfTrue);

   RenderWindow.setFramerateLimit (app, 60);

   while RenderWindow.isOpen (app) = sfTrue loop

      while RenderWindow.pollEvent (app, event => e) = sfTrue loop
         case e.eventType is
            when Event.sfEvtClosed              =>
               RenderWindow.close (app);

            when Event.sfEvtMouseButtonReleased =>
               if e.mouseButton.button = Mouse.sfMouseRight then
                  declare
                     Move_Count : constant Natural := Natural (Moves.Length);
                  begin
                     if Move_Count >= 2 then
                        declare
                           Last_Index : constant Natural := Move_Count - 1;
                           Prev_Index : constant Natural := Move_Count - 2;
                           Last_Move  : constant Vector3i :=
                             Moves.Element (Index => Last_Index);
                           Prev_Move  : constant Vector3i :=
                             Moves.Element (Index => Prev_Index);
                        begin
                           Flip_Cell (Last_Move);
                           Flip_Cell (Prev_Move);
                           Moves.Delete_Last;
                           Moves.Delete_Last;
                        end;
                     end if;
                  end;
               end if;

            when Event.sfEvtMouseButtonPressed =>
               if e.mouseButton.button = Mouse.sfMouseLeft then
                  declare
                     Mouse_Pos  : constant Vector2.sfVector2i :=
                       RenderWindow.Mouse.getPosition (app);
                     Adjusted_X : constant Integer :=
                       Integer (Mouse_Pos.x) - Desk_Offset_X;
                     Adjusted_Y : constant Integer := Integer (Mouse_Pos.y);
                  begin
                     for Z in 0 .. Board_Layers - 1 loop
                        declare
                           Local_X        : constant Integer :=
                             Floor_Int
                               ((Float (Adjusted_X) - Float (Z) * Offset_X)
                                / Float (Step_X));
                           Local_Y        : constant Integer :=
                             Floor_Int
                               ((Float (Adjusted_Y) + Float (Z) * Offset_Y)
                                / Float (Step_Y));
                           Layer_Selected : Boolean := False;
                           Candidate      : Vector3i := Current_Selection;
                        begin
                           for I in 0 .. 1 loop
                              for J in 0 .. 1 loop
                                 declare
                                    X_Pos : constant Integer := Local_X - I;
                                    Y_Pos : constant Integer := Local_Y - J;
                                 begin
                                    if Cell_Value (X_Pos, Y_Pos, Z) > 0
                                      and then Is_Open (X_Pos, Y_Pos, Z)
                                    then
                                       Candidate :=
                                         (x => X_Pos, y => Y_Pos, z => Z);
                                       Layer_Selected := True;
                                    end if;
                                 end;
                              end loop;
                           end loop;

                           if Layer_Selected then
                              Current_Selection := Candidate;

                              if Current_Selection /= Previous_Selection then
                                 declare
                                    A : constant Integer :=
                                      Cell_Value (Current_Selection);
                                    B : constant Integer :=
                                      Cell_Value (Previous_Selection);
                                 begin
                                    if (A = B and then A /= 0)
                                      or else
                                        (A > 34
                                         and then A < 39
                                         and then B > 34
                                         and then B < 39)
                                      or else (A >= 39 and then B >= 39)
                                    then
                                       Flip_Cell (Current_Selection);
                                       Moves.Append (Current_Selection);
                                       Flip_Cell (Previous_Selection);
                                       Moves.Append (Previous_Selection);
                                    end if;
                                 end;
                                 Previous_Selection := Current_Selection;
                              end if;
                           end if;
                        end;
                     end loop;
                  end;
               end if;

            when others =>
               null;
         end case;
      end loop;

      RenderWindow.clear (app);
      RenderWindow.drawSprite (app, Background_Sprite);

      for Z in 0 .. Board_Layers - 1 loop
         for X in reverse 0 .. Board_Width loop
            for Y in 0 .. Board_Height - 1 loop
               declare
                  Value : constant Integer := Cell_Value (X, Y, Z);
                  K     : constant Integer := Value - 1;
               begin
                  if K >= 0 then
                     declare
                        Rect_Left : constant Integer := K * Tile_Width;
                        Position  : constant Vector2.sfVector2f :=
                          (Float (X * Step_X) + Float (Z) * Offset_X,
                           Float (Y * Step_Y) - Float (Z) * Offset_Y);
                     begin
                        Sprite.setTextureRect
                          (Tile_Sprite,
                           (Rect_Left, 0, Tile_Width, Tile_Height));

                        if Is_Open (X, Y, Z) then
                           Sprite.setTextureRect
                             (Tile_Sprite,
                              (Rect_Left,
                               Tile_Height,
                               Tile_Width,
                               Tile_Height));
                        end if;

                        Sprite.setPosition (Tile_Sprite, Position);
                        Sprite.move
                          (Tile_Sprite, (Float (Desk_Offset_X), 0.0));
                        RenderWindow.drawSprite (app, Tile_Sprite);
                     end;
                  end if;
               end;
            end loop;
         end loop;
      end loop;

      RenderWindow.display (app);

   end loop;

   Sprite.destroy (Tile_Sprite);
   Sprite.destroy (Background_Sprite);
   Texture.destroy (Tiles_Texture);
   Texture.destroy (Background_Texture);
   RenderWindow.destroy (app);

end Mahjong;
