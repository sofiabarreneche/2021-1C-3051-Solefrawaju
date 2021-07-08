﻿using System;
using System.Collections.Generic;
using System.Text;
using System.Diagnostics;
using Microsoft.Xna.Framework;

namespace TGC.MonoGame.TP
{
    public class BackgroundCombat
    {
        public List<Ship> backgroundShips = new List<Ship>();
        TGCGame Game;

        int pairs;
        int maxPairs = 4;
        float genTimer = 0;
        float genTimerMax = 100;
        Random r;
        public BackgroundCombat() 
        {
            Game = TGCGame.Instance;
        }

        public void Generate()
        {
            var xwing = Game.Xwing;
            r = new Random();

            BoundingBox BB;
            Vector3 deltaPos;
            float distance;
            Vector3 chaserPos;
            var bbsz = new Vector3(30f);
            do
            {
                deltaPos = new Vector3(r.Next(-500, +500), 0, r.Next(-500, 500));
                chaserPos = xwing.Position + deltaPos;
                BB = new BoundingBox(chaserPos - bbsz, chaserPos + bbsz);
                distance = Vector3.DistanceSquared(chaserPos, xwing.Position);            
            } while (Game.BoundingFrustum.Intersects(BB) || distance < 40000);
            r = new Random();
            var randomFD = new Vector3(2f * (float)r.NextDouble() - 1, 0.5f * (float)r.NextDouble(), 2f * (float)r.NextDouble() - 1);
            var frontDirection = Vector3.Normalize(randomFD);
            r = new Random();
            var chasedPos = chaserPos + frontDirection * (float)(100 + 300 *r.NextDouble());

            r = new Random();
            bool allyChasing = r.NextDouble() >= 0.5;// 50% chance?

            Ship chaser, chased;

            
                chased = new Ship(chasedPos, frontDirection, !allyChasing);
                chaser = new Ship(chaserPos, frontDirection, allyChasing, chased);
            
            backgroundShips.Add(chaser);
            backgroundShips.Add(chased);

            pairs++;
            //Debug.WriteLine("pairs " + pairs);
        }
        public void UpdateGenerator(float elapsedTime)
        {
            if(genTimer < genTimerMax)
            {
                genTimer += elapsedTime * 60;
            }
            else
            {
                genTimer = 0;
                r = new Random();
                genTimerMax = r.Next(2, 5);

                if(pairs < maxPairs)
                {
                    //generate
                    Generate();
                    
                }
                
            }
            

        }
        public void UpdateAll(float elapsedTime)
        {
            UpdateGenerator(elapsedTime);

            //var prevpairs = backgroundShips.Count;

            backgroundShips.ForEach(ship => ship.Update(elapsedTime));
            backgroundShips.RemoveAll(ship => ship.ShouldBeDestroyed);

            pairs = backgroundShips.Count / 2;
            
            //if(pairs != prevpairs)
            //    Debug.WriteLine("pairs " + pairs);
            
        }
        public void AddAllRequiredToDraw(ref List<Ship> shipList)
        {
            var frustum = Game.BoundingFrustum;
            var onScreen = backgroundShips.FindAll(ship => ship.onScreen);

            foreach (var ship in onScreen)
                shipList.Add(ship);
           
        }
    }
    public class Ship
    {
        Vector3 Position;
        Vector3 FrontDirection;

        Matrix YPR;
        public Matrix SRT;
        Matrix Scale;

        bool Chasing;
        public bool ShouldBeDestroyed = false;
        public bool Allied; 
        float betweenFire = 0;
        float fireRate = 1f;

        float Yaw, Pitch, Roll = 0f;
        float age = 0f;
        int maxAge = 20;
        
        public Ship Pair;

        BoundingBox BB;
        Vector3 BBsize = new Vector3(10f, 5f, 10f);
        BoundingSphere BS;

        public bool onScreen;
        public Ship(Vector3 pos, Vector3 front, bool allyChasing) 
        {
            Position = pos;
            FrontDirection = front;
            Allied = allyChasing;
            Chasing = false;

            if (Allied)
            {
                Scale = Matrix.CreateScale(2.5f);
                BB = new BoundingBox(pos - BBsize, pos + BBsize);
            }
            else
            {
                Scale = Matrix.CreateScale(0.02f);
                BS = new BoundingSphere(pos, 10f);
            }
        }
        public Ship(Vector3 pos, Vector3 front, bool allyChasing, Ship pair) 
        {
            Position = pos;
            FrontDirection = front;
            Allied = allyChasing;
            Chasing = true;
            Pair = pair;

            if (Allied)
            {
                Scale = Matrix.CreateScale(2.5f);
                BB = new BoundingBox(pos - BBsize, pos + BBsize);
            }
            else
            {
                Scale = Matrix.CreateScale(0.02f);
                BS = new BoundingSphere(pos, 10f);
            }
        }
        
        public void Update(float elapsedTime)
        {
            Position += FrontDirection * elapsedTime * 150;

            age += elapsedTime * 60;
            betweenFire += fireRate * 30f * elapsedTime;
            var frustum = TGCGame.Instance.BoundingFrustum;

            if (Allied)
            {
                BB.Min = Position - BBsize;
                BB.Max = Position + BBsize;

                onScreen = frustum.Intersects(BB);
            }
            else
            {
                BS.Center = Position;
                onScreen = frustum.Intersects(BS);
            }

            Yaw = MathF.Atan2(FrontDirection.X, FrontDirection.Z);
            if (Yaw < 0)
                Yaw += MathHelper.TwoPi;
            Yaw %= MathHelper.TwoPi;

            Pitch = MathF.Asin(FrontDirection.Y);

            var corrYaw = (Yaw + MathHelper.Pi) % MathHelper.TwoPi;
            if (Allied) 
                YPR = Matrix.CreateFromYawPitchRoll(corrYaw, Pitch, Roll);
            else
                YPR = Matrix.CreateFromYawPitchRoll(Yaw, -Pitch, Roll);


            SRT = Scale * YPR * Matrix.CreateTranslation(Position);

            
            if (Chasing)
            {
                fireLaser();

                ShouldBeDestroyed = 
                    age >= maxAge &&
                    !onScreen &&
                    !Pair.onScreen;

                Pair.ShouldBeDestroyed = ShouldBeDestroyed;
            }
        }
        void fireLaser()
        {
            if (betweenFire < 1)
                return;
            betweenFire = 0;

            Random r = new Random();

            Matrix rotation = Matrix.CreateFromYawPitchRoll(Yaw, -Pitch, 0f);
            Matrix SRT =
                Matrix.CreateScale(new Vector3(0.07f, 0.07f, 0.4f)) *
                rotation *
                Matrix.CreateTranslation(Position);


            fireRate = (float)(0.001d + r.NextDouble() * 0.05d);
            if(Allied)
                Laser.AlliedLasers.Add(new Laser(Position, rotation, SRT, FrontDirection, new Vector3(0f, 0.8f, 0f)));
            else
                Laser.EnemyLasers.Add(new Laser(Position, rotation, SRT, FrontDirection, new Vector3(0.8f, 0f, 0f)));

        }
        
    }
}
