with Ada.Unchecked_Deallocation;

with Sf.Graphics.RenderWindow;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.Color;
with Sf.Window.Event;
with Sf.Window.Keyboard;

with Sf;

with Box2D;
with box2d.b2_math;
with box2d.b2_world;
with box2d.b2_body;
with box2d.b2_polygon_shape;
with box2d.b2_circle_shape;
with box2d.b2_fixture;

procedure Volleyball is

   use Sf.Graphics;
   use Sf.Graphics.Color;
   use Sf.Window;
   use Sf;

   use Box2D;
   use box2d.b2_math;
   use box2d.b2_world;
   use box2d.b2_body;
   use box2d.b2_polygon_shape;
   use box2d.b2_circle_shape;
   use box2d.b2_fixture;

   use type Sf.sfBool;

   Scale               : constant Real := 30.0;
   Deg                 : constant Real := 57.29577;
   Time_Step           : constant Real := 1.0 / 60.0;
   Velocity_Iterations : constant Positive := 8;
   Position_Iterations : constant Positive := 3;

   Gravity : constant b2Vec2 := to_b2Vec2 (0.0, 9.8);
   World   : b2World := to_b2World (Gravity);

   type Player_Index is range 1 .. 2;

   Player_Starts : constant array (Player_Index) of b2Vec2 :=
     (Player_Index'First => to_b2Vec2 (0.0, 2.0),
      Player_Index'Last  => to_b2Vec2 (20.0, 2.0));

   Player_Colors : constant array (Player_Index) of Color.sfColor :=
     (Player_Index'First => Color.sfRed, Player_Index'Last => Color.sfGreen);

   Players : array (Player_Index) of b2Body_ptr := (others => null);
   Ball    : b2Body_ptr := null;

   procedure Free_Polygon is new
     Ada.Unchecked_Deallocation
       (Object => b2polygonShape,
        Name   => b2polygonShape_ptr);
   procedure Free_Circle is new
     Ada.Unchecked_Deallocation
       (Object => b2circleShape,
        Name   => b2circleShape_ptr);

   procedure Set_Wall (X, Y, W, H : Real) is
      Shape      : b2polygonShape_ptr :=
        new b2polygonShape'(to_b2polygonShape);
      Def        : b2BodyDef := to_b2BodyDef;
      Rigid_Body : b2Body_ptr;
   begin
      setAsBox (Shape.all, W / Scale, H / Scale);
      Def.Kind := b2_staticBody;
      Def.position := to_b2Vec2 (X / Scale, Y / Scale);
      Rigid_Body := createBody (World, Def);
      declare
         Dummy : constant b2_Fixture.b2Fixture_ptr :=
           createFixture (Rigid_Body.all, Shape, 0.0);
      begin
         pragma Unreferenced (Dummy);
      end;
      Free_Polygon (Shape);
   end Set_Wall;

   procedure Initialize_Players is
      Def : b2BodyDef := to_b2BodyDef;
   begin
      Def.Kind := b2_dynamicBody;
      Def.fixedRotation := True;
      for Index in Player_Index loop
         Def.position := Player_Starts (Index);
         Players (Index) := createBody (World, Def);
         declare
            Upper : b2circleShape_ptr := new b2circleShape'(to_b2circleShape);
            Lower : b2circleShape_ptr := new b2circleShape'(to_b2circleShape);
         begin
            Upper.m_Radius := 32.0 / Scale;
            Upper.m_p := to_b2Vec2 (0.0, 13.0 / Scale);
            declare
               Dummy : constant b2_Fixture.b2Fixture_ptr :=
                 createFixture (Players (Index).all, Upper, 5.0);
            begin
               pragma Unreferenced (Dummy);
            end;
            Free_Circle (Upper);

            Lower.m_Radius := 25.0 / Scale;
            Lower.m_p := to_b2Vec2 (0.0, -20.0 / Scale);
            declare
               Dummy : constant b2_Fixture.b2Fixture_ptr :=
                 createFixture (Players (Index).all, Lower, 5.0);
            begin
               pragma Unreferenced (Dummy);
            end;
            Free_Circle (Lower);
         end;
         setFixedRotation (Players (Index).all, True);
      end loop;
   end Initialize_Players;

   procedure Initialize_Ball is
      Def : b2BodyDef := to_b2BodyDef;
   begin
      Def.Kind := b2_dynamicBody;
      Def.position := to_b2Vec2 (5.0, 1.0);
      Ball := createBody (World, Def);
      declare
         Shape   : b2circleShape_ptr := new b2circleShape'(to_b2circleShape);
         Fixture : b2_Fixture.b2Fixture_ptr;
      begin
         Shape.m_Radius := 32.0 / Scale;
         Fixture := createFixture (Ball.all, Shape, 0.2);
         setRestitution (Fixture.all, 0.95);
         Free_Circle (Shape);
      end;
   end Initialize_Ball;

   procedure Update_Player
     (Player_Body : b2Body_ptr;
      Move_Left   : Keyboard.sfKeyCode;
      Move_Right  : Keyboard.sfKeyCode;
      Jump_Key    : Keyboard.sfKeyCode)
   is
      Pos           : constant b2Vec2 := getPosition (Player_Body.all);
      Vel           : b2Vec2 := getLinearVelocity (Player_Body.all);
      Right_Pressed : constant Sf.sfBool := Keyboard.isKeyPressed (Move_Right);
      Left_Pressed  : constant Sf.sfBool := Keyboard.isKeyPressed (Move_Left);
   begin
      if Right_Pressed = sfTrue then
         Vel.x := 5.0;
      end if;

      if Left_Pressed = sfTrue then
         Vel.x := -5.0;
      end if;

      if Right_Pressed /= sfTrue and then Left_Pressed /= sfTrue then
         Vel.x := 0.0;
      end if;

      if Keyboard.isKeyPressed (Jump_Key) = sfTrue
        and then Pos.y * Scale >= 463.0
      then
         Vel.y := -13.0;
      end if;

      setLinearVelocity (Player_Body.all, Vel);
   end Update_Player;

   App : constant sfRenderWindow_Ptr :=
     RenderWindow.create ((800, 600, 32), "Volleyball Game!");
   E   : Event.sfEvent;

   Background_Texture : constant sfTexture_Ptr :=
     Texture.createFromFile ("images/background.png");
   Ball_Texture       : constant sfTexture_Ptr :=
     Texture.createFromFile ("images/ball.png");
   Player_Texture     : constant sfTexture_Ptr :=
     Texture.createFromFile ("images/blobby.png");

   Background_Sprite : constant sfSprite_Ptr := Sprite.create;
   Ball_Sprite       : constant sfSprite_Ptr := Sprite.create;
   Player_Sprite     : constant sfSprite_Ptr := Sprite.create;

begin

   RenderWindow.setFramerateLimit (App, 60);

   Texture.setSmooth (Background_Texture, True);
   Texture.setSmooth (Ball_Texture, True);
   Texture.setSmooth (Player_Texture, True);

   Sprite.setTexture (Background_Sprite, Background_Texture);
   Sprite.setTexture (Ball_Sprite, Ball_Texture);
   Sprite.setTexture (Player_Sprite, Player_Texture);

   Sprite.setOrigin (Player_Sprite, (75.0 / 2.0, 90.0 / 2.0));
   Sprite.setOrigin (Ball_Sprite, (32.0, 32.0));

   Set_Wall (400.0, 520.0, 2000.0, 10.0);
   Set_Wall (400.0, 450.0, 10.0, 170.0);
   Set_Wall (0.0, 0.0, 10.0, 2000.0);
   Set_Wall (800.0, 0.0, 10.0, 2000.0);

   Initialize_Players;
   Initialize_Ball;

   while RenderWindow.isOpen (App) = sfTrue loop

      while RenderWindow.pollEvent (App, event => E) = sfTrue loop
         case E.eventType is
            when Event.sfEvtClosed =>
               RenderWindow.close (App);

            when others            =>
               null;
         end case;
      end loop;

      for Iteration in 1 .. 2 loop
         step (World, Time_Step, Velocity_Iterations, Position_Iterations);
      end loop;

      Update_Player
        (Players (Player_Index'First),
         Move_Left  => Keyboard.sfKeyLeft,
         Move_Right => Keyboard.sfKeyRight,
         Jump_Key   => Keyboard.sfKeyUp);

      Update_Player
        (Players (Player_Index'Last),
         Move_Left  => Keyboard.sfKeyA,
         Move_Right => Keyboard.sfKeyD,
         Jump_Key   => Keyboard.sfKeyW);

      declare
         Vel   : constant b2Vec2 := getLinearVelocity (Ball.all);
         Speed : constant Real := Length (Vel);
      begin
         if Speed > 15.0 then
            setLinearVelocity (Ball.all, Vel * (15.0 / Speed));
         end if;
      end;

      RenderWindow.clear (App, Color.sfWhite);
      RenderWindow.drawSprite (App, Background_Sprite);

      for Index in Player_Index loop
         declare
            Pos   : constant b2Vec2 := getPosition (Players (Index).all);
            Angle : constant Real := getAngle (Players (Index).all);
         begin
            Sprite.setPosition (Player_Sprite, (Pos.x * Scale, Pos.y * Scale));
            Sprite.setRotation (Player_Sprite, Angle * Deg);
            Sprite.setColor (Player_Sprite, Player_Colors (Index));
            RenderWindow.drawSprite (App, Player_Sprite);
         end;
      end loop;

      declare
         Pos   : constant b2Vec2 := getPosition (Ball.all);
         Angle : constant Real := getAngle (Ball.all);
      begin
         Sprite.setPosition (Ball_Sprite, (Pos.x * Scale, Pos.y * Scale));
         Sprite.setRotation (Ball_Sprite, Angle * Deg);
         RenderWindow.drawSprite (App, Ball_Sprite);
      end;

      RenderWindow.display (App);
   end loop;

   Sprite.destroy (Player_Sprite);
   Sprite.destroy (Ball_Sprite);
   Sprite.destroy (Background_Sprite);

   if Player_Texture /= null then
      Texture.destroy (Player_Texture);
   end if;
   if Ball_Texture /= null then
      Texture.destroy (Ball_Texture);
   end if;
   if Background_Texture /= null then
      Texture.destroy (Background_Texture);
   end if;

   RenderWindow.destroy (App);

end Volleyball;
