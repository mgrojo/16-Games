with Sf.Graphics.RenderWindow; use Sf, Sf.Graphics, Sf.Graphics.RenderWindow;
with Sf.Graphics.Texture; use Sf.Graphics.Texture;
with Sf.Graphics.Sprite; use Sf.Graphics.Sprite;
with Sf.Graphics.Color; use Sf.Graphics.Color;
with Sf.Graphics.Rect; use Sf.Graphics.Rect;

with Sf.System.Vector2; use Sf.System.Vector2;
with Sf.Window.VideoMode; use Sf.Window.VideoMode;
with Sf.Window.Window; use Sf.Window.Window;
with Sf.Window.Event; use Sf.Window.Event;
with Sf.Window.Keyboard; use Sf.Window.Keyboard;

with Ada.Numerics.Discrete_Random;

procedure Arkanoid is

   function isCollide (s1, s2 : sfSprite_Ptr) return Boolean is
      boundsS1 : aliased constant sfFloatRect := getGlobalBounds(s1);
      boundsS2 : aliased constant sfFloatRect := getGlobalBounds(s2);
   begin
      return intersects (boundsS1'Access,
                         boundsS2'Access,
                         intersection => null) = sfTrue;
   end isCollide;

   xLimit : constant := 520;
   yLimit : constant := 450;

   app : sfRenderWindow_Ptr :=
     create ((xLimit, yLimit, 32), "Arkanoid Game!");
   t1, t2, t3, t4: sfTexture_Ptr;
   sBackground, sBall, sPaddle : sfSprite_Ptr := create;

   numberOfRows : constant := 10;
   numberOfColumns : constant := 10;
   numberOfBlocks : constant := numberOfRows * numberOfColumns;
   type t_BlockId is range 1 .. numberOfBlocks;
   blocks : array (t_BlockId) of sfSprite_Ptr := (others => create);
   n : t_BlockId := t_BlockId'First;
   e : sfEvent;

   type t_RandomY is range 2 .. 6;
   package RandomY is new Ada.Numerics.Discrete_Random (t_RandomY);
   generator : RandomY.Generator;

   dx : Float := 6.0; dy : Float := 5.0;
   b : sfVector2f;
   x, y : Float := 300.0;
begin

   RandomY.Reset (generator);
   setFramerateLimit(app, 50);

   t1 := createFromFile("images/block01.png");
   t2 := createFromFile("images/background.jpg");
   t3 := createFromFile("images/ball.png");
   t4 := createFromFile("images/paddle.png");

   setTexture(sBackground, t2);
   setTexture(sBall, t3);
   setTexture(sPaddle, t4);

   setPosition(sPaddle, (300.0, 440.0));
   setPosition(sBall, (300.0, 300.0));

   for I in 1 .. numberOfColumns loop
      for J in 1 .. numberOfRows loop
         setTexture (blocks(n), t1);
         setPosition (blocks(n), (Float(i*43), Float(j*20)));
         if n < numberOfBlocks then
            n := t_BlockId'Succ(n);
         end if;
      end loop;
   end loop;

   while isOpen(app) = sfTrue loop
      while PollEvent (app, event => e) = sfTrue loop

         if e.eventType = sfEvtClosed then
            Close (app);
         end if;

      end loop;

      move(sBall, (dx, 0.0));
      for eachBlock of blocks loop
         if isCollide(sBall, eachBlock) then
            setPosition (eachBlock, (-100.0, 0.0));
            dx := -dx;
         end if;
      end loop;

      move(sBall, (0.0, dy));
      for eachBlock of blocks loop
         if isCollide(sBall, eachBlock) then
            setPosition (eachBlock, (-100.0, 0.0));
            dy := -dy;
         end if;
      end loop;

      b := getPosition(sBall);
      if b.x < 0.0 or b.x > Float(xLimit) then
         dx := -dx;
      end if;
      if b.y < 0.0 or b.y > Float(yLimit) then
         dy := -dy;
      end if;

      if isKeyPressed (sfKeyRight) then
         move(sPaddle, (6.0, 0.0));
      end if;
      if isKeyPressed (sfKeyLeft) then
         move(sPaddle, (-6.0, 0.0));
      end if;

      if isCollide(sPaddle, sBall) then
         dy := Float(-RandomY.Random(Generator));
      end if;

      clear(app);
      drawSprite(app, sBackground);
      drawSprite(app, sBall);
      drawSprite(app, sPaddle);

      for eachBlock of blocks loop
         drawSprite(app, eachBlock);
      end loop;

      display(app);

   end loop;

   destroy(sBackground);
   destroy(sBall);
   destroy(sPaddle);
   for eachBlock of blocks loop
      destroy(eachBlock);
   end loop;
   destroy(t1);
   destroy(t2);
   destroy(t3);
   destroy(t4);
   destroy(app);
end Arkanoid;
