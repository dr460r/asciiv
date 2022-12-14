module Game.Engine
( update
)
where

import System.IO ( stdin, hReady )
import System.Random
import Data.List.Split ( splitOn )

import Game.Data.Map
import Game.Config
import Game.Renderer ( render )


{- Main Loop -}
update :: GameState -> String -> IO ()
update st@(mp, _, _, _) com = do
    
    -- fire spawning
    let sz = mapSize mp
    let tmtospawn = com == " "
    rx <- if tmtospawn then rnd else pure 0
    ry <- if tmtospawn then rnd else pure 0
    rf <- if tmtospawn then rnd else pure 0
    let rxi = abs rx `mod` fst sz -- fire x pos
    let ryi = abs ry `mod` snd sz -- fire y pos
    let rfi = if tmtospawn then abs rf `mod` 100 else 100 -- to spawn fire, random percent (if 100 it would not spawn in any case)
    let tospawnf = rfi < fireSpawnChance && canSetEffectOnTile (getTile mp (rxi, ryi)) (Fire 0 0) -- check if fire should spawn (rfi ok and can set fire effect on tile)
    let st' = if tospawnf then procCmdMap "/fire" (showTuple (rxi,ryi)) st else st
    
    -- process cmd from last stackframe
    let st'' = processCmd com st'
    render st''

    -- wait for cmd
    com' <- getKey
    update st'' com'


{-== Game State Update Logic ==-}

{- Pass Time -}
passTime :: GameState -> GameState
passTime = updateMap -- TODO: Add logic for time passing (integer that represents days, for example)

{- Update Map -}
updateMap :: GameState -> GameState
updateMap st@(mp, _, _, _) = updateTile st (getTile mp (0,0)) (0,0)

{- Update Tiles Recursively -}
updateTile :: GameState -> MapTile -> MapPos -> GameState

-- Fire Tile
updateTile (mp, rs, ac, cr) (tb, to, tu, Fire fr pw) pos@(x,y) = updateNextTile st' pos
    where 
        pw' = if pw > 0 then pw - 1 else 0
        fr' = fr + 1
        te' = if fr == fireMxLvl then NoEffect else Fire fr' pw
        (to', tu') = if fr' < fireSpreadLvl then (to, tu) else (NoObject, NoUnit) -- to destroy content of tile
        mp0 = changeTile mp pos (tb, to', tu', te')
        
        -- only if needs to spread
        spread = pw > 0 && fr == fireSpreadLvl
        mp1 = if spread then setEffectOnPos mp0 (Fire 0 pw') (x+1,y) else mp0
        mp2 = if spread then setEffectOnPos mp1 (Fire 1 pw') (x-1,y) else mp1
        mp3 = if spread then setEffectOnPos mp2 (Fire 0 pw') (x,y+1) else mp2
        mp4 = if spread then setEffectOnPos mp3 (Fire 1 pw') (x,y-1) else mp3
        
        st' = (mp4, rs, ac, cr)

-- Crop Tile
updateTile (mp, res, act, cr) (tb, Crop _, tu, te) pos = updateNextTile st' pos
    where
        c = cropFertility mp pos
        res' = res + baseCropYield + (if c > 0 then (if c > 4 then 2 else 1) else 0)
        st'  = (changeTile mp pos (tb, Crop c, tu, te), res', act, cr)

-- House Tile
updateTile (mp, rs, ac, cr) (_, House x, _, _) pos = updateNextTile st' pos
    where
        st' = (mp, rs, ac + x, cr)


-- catch-all
updateTile st _ pos = updateNextTile st pos

{- Update Next Tile - Doing Check after one Tile updates -}
updateNextTile :: GameState -> MapPos -> GameState
updateNextTile st@(mp, rs, ac, cr) pos -- pos = current position
    | pos' == (0,0) = if ac == 0 then (mp, rs, backupActions, cr) else st -- if there is no house use backupActions
    | otherwise     = updateTile st tile' pos'
    where
        pos' = nextTilePos mp pos
        tile' = getTile mp pos'


{- Get Position of next Tile -}
nextTilePos :: Map -> MapPos -> MapPos
nextTilePos mp (x,y) = (x', y')
    where msz = mapSize mp
          w = fst msz
          h = snd msz
          x' = if x+1 < w then x+1 else 0
          y' = if x' == 0 then (if y+1 < h then y+1 else 0) else y

{- Count Surrounding Tiles -}
-- fn is function that maps MapTile data to Bool (for example: hasTerrain Land Arable, that returns True if the thile is Arable)
countSurrTiles :: Map -> MapPos -> (MapTile -> Bool) -> Int
countSurrTiles mp (x,y) fn = cU + cD + cL + cR + cUL + cUR + cDL + cDR
    where
        -- checks:
        msz = mapSize mp; w = fst msz; h = snd msz
        u = x > 0; d = x < h - 1; l = x > 0; r = x < w - 1
        -- counts:
        cU = bti (u && fn (getTile mp (x, y-1))) -- Up
        cD = bti (d && fn (getTile mp (x, y+1))) -- Down
        cL = bti (l && fn (getTile mp (x-1, y))) -- Left
        cR = bti (r && fn (getTile mp (x+1, y))) -- Right
        cUL = bti (u && l && fn (getTile mp (x-1,y-1))) -- Up-Left
        cUR = bti (u && r && fn (getTile mp (x+1,y-1))) -- Up-Right
        cDL = bti (d && l && fn (getTile mp (x-1,y+1))) -- Down-Left
        cDR = bti (d && r && fn (getTile mp (x+1,y+1))) -- Down-Right


{-== Command Processing Logic ==-}

{- Combines multy-char keys into one String -}
getKey :: IO [Char]
getKey = reverse <$> getKey' ""
  where getKey' chars = do
          char <- getChar
          more <- hReady stdin
          (if more then getKey' else return) (char:chars)


{- Process cmd -}
processCmd :: String -> GameState -> GameState
-- Next Turn (Pass time)
processCmd " " (m, r, _, c) = passTime (m, r, 0, c)
processCmd "\n" st = processCmd " " st -- alternative (Linux only)
-- Cursor movement
processCmd "i" st = procCmdMap "cursor" "up" st
processCmd "k" st = procCmdMap "cursor" "down" st
processCmd "l" st = procCmdMap "cursor" "right" st
processCmd "j" st = procCmdMap "cursor" "left" st
-- alternatives (Linux only)
processCmd "\ESC[A" st = processCmd "i" st
processCmd "\ESC[B" st = processCmd "k" st
processCmd "\ESC[C" st = processCmd "l" st
processCmd "\ESC[D" st = processCmd "j" st
-- Other Actions
processCmd "x" st@(_, _, _, cr) = procCmdMap "house" (showTuple cr) st
processCmd "c" st@(_, _, _, cr) = procCmdMap "crop" (showTuple cr) st
processCmd "v" st@(_, _, _, cr) = procCmdMap "fight" (showTuple cr) st
-- alternatives
processCmd "h" st = processCmd "x" st
processCmd "u" st = processCmd "c" st
processCmd "y" st = processCmd "v" st
-- DEV COMMANDS
processCmd "w" st@(_, _, _, cr) = procCmdMap "/water" (showTuple cr) st
processCmd "f" st@(_, _, _, cr) = procCmdMap "/fire" (showTuple cr) st
processCmd _ st = procCmdMap "" "" st


{- Command Mappings -}
procCmdMap :: String -> String -> GameState -> GameState

-- Spawn Crop
procCmdMap "crop" prm st@(mp, _, _, _) = spawnObject st pos (Crop (cropFertility mp pos)) cropPrice cropActons
    where pos = strToPos prm

-- Spawn House
procCmdMap "house" prm st = spawnObject st pos (House housePop) housePrice houseActions
    where pos = strToPos prm

-- Fight Fire (or other disasters)
procCmdMap "fight" prm st@(mp, res, act, cr) = st'
    where
        canfight = res - fightCost >= 0 && act - fightActions >= 0
        mp' = setEffectOnPos mp NoEffect (strToPos prm)
        st' = if canfight then (mp', res - fightCost, act - fightActions, cr) else st
        

-- Cursor movements
procCmdMap "cursor" "up"    (mp, rs, ac, (x,y)) = (mp, rs, ac, (x,y')) where y' = if y-1 >= 0 then y-1 else y
procCmdMap "cursor" "down"  (mp, rs, ac, (x,y)) = (mp, rs, ac, (x,y')) where y' = if y+1 < snd (mapSize mp) then y+1 else y
procCmdMap "cursor" "right" (mp, rs, ac, (x,y)) = (mp, rs, ac, (x',y)) where x' = if x+1 < fst (mapSize mp) then x+1 else x
procCmdMap "cursor" "left"  (mp, rs, ac, (x,y)) = (mp, rs, ac, (x',y)) where x' = if x-1 >= 0 then x-1 else x

-- Spawn Water (DEV COMMAND)
procCmdMap "/water" prm (mp, res, act, cr) = (changeTile mp pos tile', res, act, cr)
    where
        pos = strToPos prm
        (_, to, tu, te) = getTile mp pos
        tile' = (Water Fresh, to, tu, te)

-- Spawn Fire (DEV COMMAND)
procCmdMap "/fire" prm (mp, res, act, cr) = (changeTile mp pos tile', res, act, cr)
    where
        pos = strToPos prm
        (tb, to, tu, _) = getTile mp pos
        tile' = (tb, to, tu, Fire 0 fireSpreadDistance)
        -- (tb, _, _, _) = getTile mp pos
        -- tile' = (tb, NoObject, NoUnit, Fire 1 fireSpreadDistance)

-- catch-all
procCmdMap _ _ st = st


{-== Command Processing Utils ==-}
spawnObject :: GameState -> MapPos -> Object -> Int -> Int -> GameState
spawnObject st@(mp, res, act, cr) pos obj cost acost = if valid then (changeTile mp pos tile', res - cost, act - acost, cr) else st
    where
        tile@(tb, _, tu, te) = getTile mp pos
        tile' = (tb, obj, tu, te)
        valid = tileValidity tile' && res - cost >= 0 && act - acost >= 0 && canBuildOnTile tile



tileValidity :: MapTile -> Bool
tileValidity (Land _, _, _, Fire _ _) = True
tileValidity (Land _, NoObject, _, _) = True
tileValidity (Water _, NoObject, _, _) = True
tileValidity (Land Arable, Crop _, _, _) = True
tileValidity (Land _, House _, _, _) = True
tileValidity _ = False

canBuildOnTile :: MapTile -> Bool
canBuildOnTile (_, NoObject, _, _) = True
canBuildOnTile (_, _, _, _) = False


{-== Crop Utils ==-}
cropFertility :: Map -> MapPos -> Int
cropFertility mp pos = countSurrTiles mp pos (hasTerrain (Water Fresh))


{-== World Behaviour ==-}

-- doWorldEvents :: GameState -> GameState
-- doWorldEvents st = do

--maybeRandomSpawnFire :: Map -> Map



{-== Utils ==-}

-- " abc  " -> "abc"
trim :: String -> String
trim = unwords . words

-- "3,5" -> (3,5)
strToPos :: String -> MapPos
strToPos s = (rdtr (head ar) :: Int, rdtr (ar !! 1) :: Int)
            where ar = splitOn "," s; rdtr = read . trim

bti :: Bool -> Int
bti True = 1
bti False = 0

showTuple :: Show a => (a,a) -> String
showTuple (x,y) = show x ++ "," ++ show y

rnd :: IO Int
rnd = randomIO :: IO Int