with Sf.Graphics.RenderWindow;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.Color;
with Sf.Graphics.ConvexShape;

with Sf.Window.Event;
with Sf.Window.Keyboard;

with Ada.Containers.Vectors;
with Ada.Numerics.Discrete_Random;

procedure Tron is

   use Sf.Graphics;
   use Sf.Graphics.Color;
   use Sf.Window;
   use Sf;

   W : constant sfInt32 := 600;
   H : constant sfInt32 := 480;
   Speed : constant Positive := 4;
   Trail_Size : constant Float := 3.0;

   type Direction is (Down, Left, Right, Up);

   subtype X_Index is sfInt32 range 0 .. W - 1;
   subtype Y_Index is sfInt32 range 0 .. H - 1;

   type Field_Array is array (X_Index, Y_Index) of Boolean;
   Field : Field_Array := (others => (others => False));

   type Position is record
      X : sfInt32;
      Y : sfInt32;
   end record;

   subtype Trail_Index is Positive;

   package Trail_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Trail_Index,
      Element_Type => Position);

   type Player is record
      X, Y  : sfInt32 := 0;
      Dir   : Direction := Right;
      Shade : Color.sfColor;
   end record;

   subtype Player_Index is Positive range 1 .. 2;

    Player_Colors : constant array (Player_Index) of Color.sfColor :=
       (1 => Color.sfRed,
         2 => (0, 255, 0, 255));

   Players : array (Player_Index) of Player :=
       (others => (X => 0, Y => 0, Dir => Right, Shade => Color.sfWhite));

   Trails : array (Player_Index) of Trail_Vectors.Vector;

   package Random_X is new Ada.Numerics.Discrete_Random (X_Index);
   package Random_Y is new Ada.Numerics.Discrete_Random (Y_Index);
   package Random_Direction is new Ada.Numerics.Discrete_Random (Direction);

   X_Generator   : Random_X.Generator;
   Y_Generator   : Random_Y.Generator;
   Dir_Generator : Random_Direction.Generator;

    App : constant sfRenderWindow_Ptr :=
       RenderWindow.create ((sfUint32 (W), sfUint32 (H), 32), "The Tron Game!");
   E   : Event.sfEvent;

    Background_Texture : constant sfTexture_Ptr :=
       Texture.createFromFile ("background.jpg");
    Background_Sprite  : constant sfSprite_Ptr := Sprite.create;

   Trail_Shapes : array (Player_Index) of sfConvexShape_Ptr :=
     (others => null);

   Game : Boolean := True;

   function Cell_Occupied (X, Y : sfInt32) return Boolean is
     (Field (X_Index (X), Y_Index (Y)));

   function Opposite (Value : Direction) return Direction is
   begin
      case Value is
         when Down  => return Up;
         when Up    => return Down;
         when Left  => return Right;
         when Right => return Left;
      end case;
   end Opposite;

   procedure Set_Direction (Id : Player_Index; Desired : Direction) is
   begin
      if Players (Id).Dir /= Opposite (Desired) then
         Players (Id).Dir := Desired;
      end if;
   end Set_Direction;

   procedure Advance (Self : in out Player) is
   begin
      case Self.Dir is
         when Down  => Self.Y := Self.Y + 1;
         when Left  => Self.X := Self.X - 1;
         when Right => Self.X := Self.X + 1;
         when Up    => Self.Y := Self.Y - 1;
      end case;

      if Self.X >= W then
         Self.X := 0;
      elsif Self.X < 0 then
         Self.X := W - 1;
      end if;

      if Self.Y >= H then
         Self.Y := 0;
      elsif Self.Y < 0 then
         Self.Y := H - 1;
      end if;
   end Advance;

   procedure Occupy_Cell (Id : Player_Index) is
      Xi : constant X_Index := X_Index (Players (Id).X);
      Yi : constant Y_Index := Y_Index (Players (Id).Y);
   begin
      Field (Xi, Yi) := True;
      Trails (Id).Append ((X => Players (Id).X, Y => Players (Id).Y));
   end Occupy_Cell;

   procedure Initialize_Player (Id : Player_Index) is
      X : sfInt32;
      Y : sfInt32;
   begin
      loop
         X := sfInt32 (Random_X.Random (X_Generator));
         Y := sfInt32 (Random_Y.Random (Y_Generator));
         exit when not Cell_Occupied (X, Y);
      end loop;

      Players (Id).X := X;
      Players (Id).Y := Y;
      Players (Id).Dir := Random_Direction.Random (Dir_Generator);
      Occupy_Cell (Id);
   end Initialize_Player;

   procedure Draw_Trail (Id : Player_Index) is
      Trail : Trail_Vectors.Vector renames Trails (Id);
      Shape : sfConvexShape_Ptr renames Trail_Shapes (Id);
      Half_Size : constant Float := Trail_Size / 2.0;
   begin
      if Trail.Is_Empty then
         return;
      end if;

      for Index in Trail.First_Index .. Trail.Last_Index loop
         declare
            Point  : constant Position := Trail.Element (Index);
            Left   : constant Float := Float (Point.X) - Half_Size;
            Top    : constant Float := Float (Point.Y) - Half_Size;
            Right  : constant Float := Left + Trail_Size;
            Bottom : constant Float := Top + Trail_Size;
         begin
            ConvexShape.setPoint (Shape, 0, (Left, Top));
            ConvexShape.setPoint (Shape, 1, (Right, Top));
            ConvexShape.setPoint (Shape, 2, (Right, Bottom));
            ConvexShape.setPoint (Shape, 3, (Left, Bottom));
            RenderWindow.drawConvexShape (App, Shape);
         end;
      end loop;
   end Draw_Trail;

begin

   Random_X.Reset (X_Generator);
   Random_Y.Reset (Y_Generator);
   Random_Direction.Reset (Dir_Generator);

   Sprite.setTexture (Background_Sprite, Background_Texture);

   for Id in Player_Index loop
   Players (Id).Shade := Player_Colors (Id);
      Trail_Shapes (Id) := ConvexShape.create;
      ConvexShape.setPointCount (Trail_Shapes (Id), 4);
   ConvexShape.setFillColor (Trail_Shapes (Id), Players (Id).Shade);
      Trails (Id).Clear;
   end loop;

   for Id in Player_Index loop
      Initialize_Player (Id);
   end loop;

   RenderWindow.setFramerateLimit (App, 60);

   while RenderWindow.isOpen (App) = sfTrue loop

      while RenderWindow.PollEvent (App, event => E) = sfTrue loop
         case E.eventType is
            when Event.sfEvtClosed =>
               RenderWindow.close (App);
            when others =>
               null;
         end case;
      end loop;

      if Keyboard.isKeyPressed (Keyboard.sfKeyLeft) = sfTrue then
         Set_Direction (1, Left);
      end if;
      if Keyboard.isKeyPressed (Keyboard.sfKeyRight) = sfTrue then
         Set_Direction (1, Right);
      end if;
      if Keyboard.isKeyPressed (Keyboard.sfKeyUp) = sfTrue then
         Set_Direction (1, Up);
      end if;
      if Keyboard.isKeyPressed (Keyboard.sfKeyDown) = sfTrue then
         Set_Direction (1, Down);
      end if;

      if Keyboard.isKeyPressed (Keyboard.sfKeyA) = sfTrue then
         Set_Direction (2, Left);
      end if;
      if Keyboard.isKeyPressed (Keyboard.sfKeyD) = sfTrue then
         Set_Direction (2, Right);
      end if;
      if Keyboard.isKeyPressed (Keyboard.sfKeyW) = sfTrue then
         Set_Direction (2, Up);
      end if;
      if Keyboard.isKeyPressed (Keyboard.sfKeyS) = sfTrue then
         Set_Direction (2, Down);
      end if;

      if Game then
         Step_Loop :
         for Step in 1 .. Speed loop
            for Id in Player_Index loop
               Advance (Players (Id));
            end loop;

            for Id in Player_Index loop
               if Cell_Occupied (Players (Id).X, Players (Id).Y) then
                  Game := False;
               end if;
            end loop;

            for Id in Player_Index loop
               Occupy_Cell (Id);
            end loop;

            exit Step_Loop when not Game;
         end loop Step_Loop;
      end if;

      RenderWindow.clear (App);
      RenderWindow.drawSprite (App, Background_Sprite);

      for Id in Player_Index loop
         Draw_Trail (Id);
      end loop;

      RenderWindow.display (App);

   end loop;

   for Id in Player_Index loop
      ConvexShape.destroy (Trail_Shapes (Id));
   end loop;

   Sprite.destroy (Background_Sprite);
   Texture.destroy (Background_Texture);

end Tron;
