with Sf.Graphics.RenderWindow;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.Color;
with Sf.Graphics.Rect;
with Sf.Window.Event;
with Sf.Window.Keyboard;

with Ada.Numerics.Elementary_Functions;
with Ada.Numerics.Float_Random;
with Ada.Containers.Vectors;
with Ada.Containers.Doubly_Linked_Lists;
with Ada.Unchecked_Deallocation;

procedure Asteroids is

   use Sf.Graphics;
   use Sf.Graphics.Color;
   use Sf.Window;                                                                               
   use Sf.Window.Event;
   use Sf;
   use Ada.Numerics.Elementary_Functions;
   use type Sf.Window.Keyboard.sfKeyCode;
   use Sf.Graphics.Rect;
   use type Ada.Containers.Count_Type;

   Screen_Width  : constant Integer := 1200;
   Screen_Height : constant Integer := 800;
   Deg_To_Rad    : constant Float := 0.017453;

    package Frame_Vectors is new Ada.Containers.Vectors
       (Index_Type   => Positive,
         Element_Type => sfIntRect,
         "="         => "=");


   type Animation is record
      Frame  : Float := 0.0;
      Speed  : Float := 0.0;
      Sprite : sfSprite_Ptr := null;
      Frames : Frame_Vectors.Vector;
   end record;

   procedure Initialize_Animation
     (Anim   : in out Animation;
      Tex    : sfTexture_Ptr;
      X, Y   : Integer;
      W, H   : Integer;
      Count  : Positive;
      Speed  : Float) is
   begin
      Anim.Frame := 0.0;
      Anim.Speed := Speed;
      Anim.Frames.Clear;
      for Index in 0 .. Count - 1 loop
         declare
            Offset : constant Integer := Index * W;
         begin
            Anim.Frames.Append ((X + Offset, Y, W, H));
         end;
      end loop;

      if Anim.Sprite = null then
         Anim.Sprite := Sprite.create;
      end if;

      Sprite.setTexture (Anim.Sprite, Tex);
         Sprite.setOrigin
            (Anim.Sprite,
             (Float (W) / 2.0, Float (H) / 2.0));

      if Anim.Frames.Length > 0 then
         declare
            First_Index : constant Positive := Anim.Frames.First_Index;
         begin
            Sprite.setTextureRect
              (Anim.Sprite, rectangle => Anim.Frames.Element (First_Index));
         end;
      end if;
   end Initialize_Animation;

   function Clone_Animation (Source : Animation) return Animation is
      Result : Animation := Source;
   begin
      if Source.Sprite /= null then
         Result.Sprite := Sprite.copy (Source.Sprite);
      else
         Result.Sprite := null;
      end if;
      return Result;
   end Clone_Animation;

   procedure Destroy_Animation (Anim : in out Animation) is
   begin
      if Anim.Sprite /= null then
         Sprite.destroy (Anim.Sprite);
         Anim.Sprite := null;
      end if;
      Anim.Frames.Clear;
      Anim.Frame := 0.0;
      Anim.Speed := 0.0;
   end Destroy_Animation;

   procedure Update_Animation (Anim : in out Animation) is
      Count : constant Natural := Natural (Anim.Frames.Length);
   begin
      if Count = 0 or else Anim.Sprite = null then
         return;
      end if;

      Anim.Frame := Anim.Frame + Anim.Speed;
      while Anim.Frame >= Float (Count) loop
         Anim.Frame := Anim.Frame - Float (Count);
      end loop;

      declare
         Base_Index : constant Integer := Integer (Anim.Frames.First_Index);
         Offset     : constant Integer := Integer (Float'Floor (Anim.Frame));
         Rect_Index : constant Positive := Positive (Base_Index + Offset);
      begin
         Sprite.setTextureRect
           (Anim.Sprite, rectangle => Anim.Frames.Element (Rect_Index));
      end;
   end Update_Animation;

   function Animation_Is_End (Anim : Animation) return Boolean is
      Count : constant Natural := Natural (Anim.Frames.Length);
   begin
      if Count = 0 then
         return True;
      end if;
      return Anim.Frame + Anim.Speed >= Float (Count);
   end Animation_Is_End;

   type Entity_Kind is (Asteroid, Bullet, Player, Explosion);

   type Entity;
   type Entity_Access is access all Entity;

   package Entity_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Entity_Access,
      "="         => "=");

   type Entity is record
      Kind   : Entity_Kind := Explosion;
      X, Y   : Float := 0.0;
      DX, DY : Float := 0.0;
      R      : Float := 1.0;
      Angle  : Float := 0.0;
      Life   : Boolean := True;
      Thrust : Boolean := False;
      Anim   : Animation;
   end record;

   procedure Destroy_Entity (Item : in out Entity) is
   begin
      Destroy_Animation (Item.Anim);
   end Destroy_Entity;

   procedure Free_Entity is new Ada.Unchecked_Deallocation (Entity, Entity_Access);

   package Entity_Lists is new Ada.Containers.Doubly_Linked_Lists (Entity_Access);
   Entities : Entity_Lists.List;
   use type Entity_Lists.Cursor;

   package Random_Float renames Ada.Numerics.Float_Random;
   Generator : Random_Float.Generator;

   function Random_Int (Min, Max : Integer) return Integer is
      Span : constant Integer := Max - Min + 1;
   begin
      return Min + Integer (Float (Span) * Random_Float.Random (Generator));
   end Random_Int;

   function Random_Angle return Float is
   begin
      return Float (Random_Int (0, 359));
   end Random_Angle;

   procedure Wrap_Value (Value : in out Float; Limit : Float) is
   begin
      if Value > Limit then
         Value := 0.0;
      elsif Value < 0.0 then
         Value := Limit;
      end if;
   end Wrap_Value;

   procedure Wrap_Entity (Item : in out Entity) is
   begin
      Wrap_Value (Item.X, Float (Screen_Width));
      Wrap_Value (Item.Y, Float (Screen_Height));
   end Wrap_Entity;

   procedure Randomize_Asteroid_Velocity (Item : in out Entity) is
   begin
      loop
         Item.DX := Float (Random_Int (-4, 3));
         Item.DY := Float (Random_Int (-4, 3));
         exit when Item.DX /= 0.0 or else Item.DY /= 0.0;
      end loop;
   end Randomize_Asteroid_Velocity;

   function Create_Entity
     (Kind   : Entity_Kind;
      Model  : Animation;
      X, Y   : Float;
      Angle  : Float;
      Radius : Float) return Entity_Access is
      Result : constant Entity_Access := new Entity;
   begin
      Result.Kind  := Kind;
      Result.X     := X;
      Result.Y     := Y;
      Result.Angle := Angle;
      Result.R     := Radius;
      Result.Life  := True;
      Result.Anim  := Clone_Animation (Model);
      return Result;
   end Create_Entity;

   procedure Update_Entity (Item : in out Entity) is
      Max_Speed : constant Float := 15.0;
   begin
      case Item.Kind is
         when Asteroid =>
            Item.X := Item.X + Item.DX;
            Item.Y := Item.Y + Item.DY;
            Wrap_Entity (Item);

         when Bullet =>
            Item.DX := Cos (Item.Angle * Deg_To_Rad) * 6.0;
            Item.DY := Sin (Item.Angle * Deg_To_Rad) * 6.0;
            Item.X := Item.X + Item.DX;
            Item.Y := Item.Y + Item.DY;
            if Item.X > Float (Screen_Width) or else Item.X < 0.0
              or else Item.Y > Float (Screen_Height) or else Item.Y < 0.0
            then
               Item.Life := False;
            end if;

         when Player =>
            if Item.Thrust then
               Item.DX := Item.DX + Cos (Item.Angle * Deg_To_Rad) * 0.2;
               Item.DY := Item.DY + Sin (Item.Angle * Deg_To_Rad) * 0.2;
            else
               Item.DX := Item.DX * 0.99;
               Item.DY := Item.DY * 0.99;
            end if;

            declare
               Speed : constant Float := Sqrt (Item.DX * Item.DX + Item.DY * Item.DY);
            begin
               if Speed > Max_Speed then
                  Item.DX := Item.DX * Max_Speed / Speed;
                  Item.DY := Item.DY * Max_Speed / Speed;
               end if;
            end;

            Item.X := Item.X + Item.DX;
            Item.Y := Item.Y + Item.DY;
            Wrap_Entity (Item);

         when Explosion =>
            null;
      end case;
   end Update_Entity;

   function Is_Collide (A, B : Entity) return Boolean is
      DX : constant Float := B.X - A.X;
      DY : constant Float := B.Y - A.Y;
      RS : constant Float := A.R + B.R;
   begin
      return DX * DX + DY * DY < RS * RS;
   end Is_Collide;

   App : constant sfRenderWindow_Ptr :=
     RenderWindow.create
       ((sfUint32 (Screen_Width), sfUint32 (Screen_Height), sfUint32 (32)),
            "Asteroids!");
   Evt : Sf.Window.Event.sfEvent;

   Background_Texture : constant sfTexture_Ptr := Texture.createFromFile ("images/background.jpg");
   Background_Sprite  : constant sfSprite_Ptr := Sprite.create;

   Ship_Texture        : constant sfTexture_Ptr := Texture.createFromFile ("images/spaceship.png");
   Rock_Texture        : constant sfTexture_Ptr := Texture.createFromFile ("images/rock.png");
   Fire_Texture        : constant sfTexture_Ptr := Texture.createFromFile ("images/fire_blue.png");
   Small_Rock_Texture  : constant sfTexture_Ptr := Texture.createFromFile ("images/rock_small.png");
   Explosion_C_Texture : constant sfTexture_Ptr := Texture.createFromFile ("images/explosions/type_C.png");
   Explosion_B_Texture : constant sfTexture_Ptr := Texture.createFromFile ("images/explosions/type_B.png");

   Explosion_Anim      : Animation;
   Rock_Anim           : Animation;
   Rock_Small_Anim     : Animation;
   Bullet_Anim         : Animation;
   Player_Anim         : Animation;
   Player_Thrust_Anim  : Animation;
   Ship_Explosion_Anim : Animation;

   Player_Entity       : Entity_Access := null;
   Player_Thrust_Last  : Boolean := False;

begin

   Random_Float.Reset (Generator);

   RenderWindow.setFramerateLimit (App, 60);

   Texture.setSmooth (Ship_Texture, True);
   Texture.setSmooth (Background_Texture, True);

   Sprite.setTexture (Background_Sprite, Background_Texture);

   Initialize_Animation (Explosion_Anim, Explosion_C_Texture, 0, 0, 256, 256, 48, 0.5);
   Initialize_Animation (Rock_Anim, Rock_Texture, 0, 0, 64, 64, 16, 0.2);
   Initialize_Animation (Rock_Small_Anim, Small_Rock_Texture, 0, 0, 64, 64, 16, 0.2);
   Initialize_Animation (Bullet_Anim, Fire_Texture, 0, 0, 32, 64, 16, 0.8);
   Initialize_Animation (Player_Anim, Ship_Texture, 40, 0, 40, 40, 1, 0.0);
   Initialize_Animation (Player_Thrust_Anim, Ship_Texture, 40, 40, 40, 40, 1, 0.0);
   Initialize_Animation (Ship_Explosion_Anim, Explosion_B_Texture, 0, 0, 192, 192, 64, 0.5);

   for I in 1 .. 15 loop
      declare
         Ast : constant Entity_Access :=
           Create_Entity
             (Asteroid,
              Rock_Anim,
              Float (Random_Int (0, Screen_Width - 1)),
              Float (Random_Int (0, Screen_Height - 1)),
              Random_Angle,
              25.0);
      begin
         Randomize_Asteroid_Velocity (Ast.all);
         Entities.Append (Ast);
      end;
   end loop;

   Player_Entity :=
     Create_Entity (Player, Player_Anim, 200.0, 200.0, 0.0, 20.0);
   Entities.Append (Player_Entity);

   while RenderWindow.isOpen (App) = sfTrue loop

      while RenderWindow.PollEvent (App, event => Evt) = sfTrue loop
         case Evt.eventType is
            when Event.sfEvtClosed =>
               RenderWindow.close (App);
            when Event.sfEvtKeyPressed =>
               if Evt.key.code = Keyboard.sfKeySpace and then Player_Entity /= null then
                  declare
                     New_Bullet : constant Entity_Access :=
                       Create_Entity
                         (Bullet,
                          Bullet_Anim,
                          Player_Entity.X,
                          Player_Entity.Y,
                          Player_Entity.Angle,
                          10.0);
                  begin
                     Entities.Append (New_Bullet);
                  end;
               end if;
            when others =>
               null;
         end case;
      end loop;

      if Player_Entity /= null then
         if Keyboard.isKeyPressed (Keyboard.sfKeyRight) = sfTrue then
            Player_Entity.Angle := Player_Entity.Angle + 3.0;
         end if;
         if Keyboard.isKeyPressed (Keyboard.sfKeyLeft) = sfTrue then
            Player_Entity.Angle := Player_Entity.Angle - 3.0;
         end if;

         if Keyboard.isKeyPressed (Keyboard.sfKeyUp) = sfTrue then
            Player_Entity.Thrust := True;
         else
            Player_Entity.Thrust := False;
         end if;

         if Player_Entity.Thrust /= Player_Thrust_Last then
            Destroy_Animation (Player_Entity.Anim);
            if Player_Entity.Thrust then
               Player_Entity.Anim := Clone_Animation (Player_Thrust_Anim);
            else
               Player_Entity.Anim := Clone_Animation (Player_Anim);
            end if;
            Player_Thrust_Last := Player_Entity.Thrust;
         end if;
      end if;

      declare
         Snapshot : Entity_Vectors.Vector;
         Cursor   : Entity_Lists.Cursor := Entities.First;

         procedure Handle_Asteroid_Bullet (Rock, Shot : Entity_Access) is
         begin
            if Rock = null or else Shot = null then
               return;
            end if;

            if Rock.Kind = Asteroid and then Shot.Kind = Bullet then
               if Is_Collide (Rock.all, Shot.all) then
                  Rock.Life := False;
                  Shot.Life := False;

                  declare
                     Expl : constant Entity_Access :=
                       Create_Entity (Explosion, Explosion_Anim, Rock.X, Rock.Y, 0.0, 0.0);
                  begin
                     Entities.Append (Expl);
                  end;

                  if Rock.R /= 15.0 then
                     for I in 1 .. 2 loop
                        declare
                           Small : constant Entity_Access :=
                             Create_Entity
                               (Asteroid,
                                Rock_Small_Anim,
                                Rock.X,
                                Rock.Y,
                                Random_Angle,
                                15.0);
                        begin
                           Randomize_Asteroid_Velocity (Small.all);
                           Entities.Append (Small);
                        end;
                     end loop;
                  end if;
               end if;
            end if;
         end Handle_Asteroid_Bullet;

         procedure Handle_Player_Hit (Hero, Rock : Entity_Access) is
         begin
            if Hero = null or else Rock = null then
               return;
            end if;

            if Hero.Kind = Player and then Rock.Kind = Asteroid then
               if Is_Collide (Hero.all, Rock.all) then
                  Rock.Life := False;

                  declare
                     Expl : constant Entity_Access :=
                       Create_Entity (Explosion, Ship_Explosion_Anim, Hero.X, Hero.Y, 0.0, 0.0);
                  begin
                     Entities.Append (Expl);
                  end;

                  Hero.X := Float (Screen_Width) / 2.0;
                  Hero.Y := Float (Screen_Height) / 2.0;
                  Hero.DX := 0.0;
                  Hero.DY := 0.0;
                  Hero.Angle := 0.0;
                  Hero.Thrust := False;

                  Destroy_Animation (Hero.Anim);
                  Hero.Anim := Clone_Animation (Player_Anim);
                  Player_Thrust_Last := False;
               end if;
            end if;
         end Handle_Player_Hit;

      begin
         while Cursor /= Entity_Lists.No_Element loop
            Entity_Vectors.Append (Snapshot, Entity_Lists.Element (Cursor));
            Cursor := Entity_Lists.Next (Cursor);
         end loop;

         if not Entity_Vectors.Is_Empty (Snapshot) then
            declare
               First : constant Integer := Integer (Entity_Vectors.First_Index (Snapshot));
               Last  : constant Integer := Integer (Entity_Vectors.Last_Index (Snapshot));
            begin
               for I in First .. Last loop
                  declare
                     A : constant Entity_Access :=
                       Entity_Vectors.Element (Snapshot, Positive (I));
                  begin
                     if A = null or else I = Last then
                        null;
                     else
                        for J in I + 1 .. Last loop
                           declare
                              B : constant Entity_Access :=
                                Entity_Vectors.Element (Snapshot, Positive (J));
                           begin
                              Handle_Asteroid_Bullet (A, B);
                              Handle_Asteroid_Bullet (B, A);
                              Handle_Player_Hit (A, B);
                              Handle_Player_Hit (B, A);
                           end;
                        end loop;
                     end if;
                  end;
               end loop;
            end;
         end if;
      end;

      for Cursor in Entities.Iterate loop
         declare
            Item : constant Entity_Access := Entity_Lists.Element (Cursor);
         begin
            Update_Entity (Item.all);
            Update_Animation (Item.Anim);
            if Item.Kind = Explosion and then Animation_Is_End (Item.Anim) then
               Item.Life := False;
            end if;
         end;
      end loop;

      if Random_Int (0, 149) = 0 then
         declare
            Ast : constant Entity_Access :=
              Create_Entity
                (Asteroid,
                 Rock_Anim,
                 0.0,
                 Float (Random_Int (0, Screen_Height - 1)),
                 Random_Angle,
                 25.0);
         begin
            Randomize_Asteroid_Velocity (Ast.all);
            Entities.Append (Ast);
         end;
      end if;

      declare
         Cursor : Entity_Lists.Cursor := Entities.First;
      begin
         while Cursor /= Entity_Lists.No_Element loop
            declare
               Next : constant Entity_Lists.Cursor := Entity_Lists.Next (Cursor);
               Item : Entity_Access := Entity_Lists.Element (Cursor);
            begin
               if Item = null then
                  null;
               elsif not Item.Life then
                  Destroy_Entity (Item.all);
                  Free_Entity (Item);
                  Entity_Lists.Delete (Container => Entities, Position => Cursor);
               end if;
               Cursor := Next;
            end;
         end loop;
      end;

      RenderWindow.clear (App, Color => Color.sfBlack);
      RenderWindow.drawSprite (App, Background_Sprite);
      for Cursor in Entities.Iterate loop
         declare
            Item : constant Entity_Access := Entity_Lists.Element (Cursor);
         begin
            if Item /= null and then Item.Anim.Sprite /= null then
               Sprite.setPosition (Item.Anim.Sprite, (Item.X, Item.Y));
               Sprite.setRotation (Item.Anim.Sprite, Item.Angle + 90.0);
               RenderWindow.drawSprite (App, Item.Anim.Sprite);
            end if;
         end;
      end loop;
      RenderWindow.display (App);

   end loop;

   declare
      Cursor : Entity_Lists.Cursor := Entities.First;
   begin
      while Cursor /= Entity_Lists.No_Element loop
         declare
            Item : Entity_Access := Entity_Lists.Element (Cursor);
         begin
            if Item /= null then
               Destroy_Entity (Item.all);
               Free_Entity (Item);
            end if;
         end;
         Cursor := Entity_Lists.Next (Cursor);
      end loop;
   end;

   Destroy_Animation (Explosion_Anim);
   Destroy_Animation (Rock_Anim);
   Destroy_Animation (Rock_Small_Anim);
   Destroy_Animation (Bullet_Anim);
   Destroy_Animation (Player_Anim);
   Destroy_Animation (Player_Thrust_Anim);
   Destroy_Animation (Ship_Explosion_Anim);

   Sprite.destroy (Background_Sprite);
   Texture.destroy (Background_Texture);
   Texture.destroy (Ship_Texture);
   Texture.destroy (Rock_Texture);
   Texture.destroy (Fire_Texture);
   Texture.destroy (Small_Rock_Texture);
   Texture.destroy (Explosion_C_Texture);
   Texture.destroy (Explosion_B_Texture);

end Asteroids;
