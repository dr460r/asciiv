module Game.Engine
( update
, GameState
)
where

import Data.List.Split ( splitOn )
import Game.Renderer ( render )
import Game.Data.Map


{- Main Loop -}
update :: GameState -> String -> IO ()
update st com = do
    let st' = processCmd com st
    render st'
    com' <- getLine
    update (passTime st') com'


{-== Game State Update Logic ==-}

{- Pass Time -}
passTime :: GameState -> GameState
passTime = updateMap -- TODO: Add logic for time passing (integer that represents days, for example)

{- Update Map -}
updateMap :: GameState -> GameState
updateMap st@(mp, _) = updateTile st (getTile mp p) p where p = (0,0)

{- Update Tiles Recursively -}
updateTile :: GameState -> MapTile -> MapPos -> GameState
-- Crop Tile
updateTile (mp, res) (tb, Crop c, tu, te) pos
    | pos' == (0,0) = st'
    | otherwise     = updateTile st' (getTile mp pos') pos'
    where
        c' = cropFertility mp pos
        res' = res + 1 + c'
        st'  = (changeTile mp pos (tb, Crop c', tu, te), res')
        pos' = nextTilePos mp pos
-- catch-all
updateTile st@(mp, _) _ pos
    | pos' == (0,0) = st
    | otherwise     = updateTile st (getTile mp pos') pos'
    where
        pos' = nextTilePos mp pos

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

{- Process cmd -}
processCmd :: String -> GameState -> GameState
processCmd cmd = procCmdMap (head cmd') (cmd' !! 1)
                where cmd' = splitOn " " cmd


{- Command Mappings -}
procCmdMap :: String -> String -> GameState -> GameState
-- Spawn Crop
procCmdMap "+p" "" st = st   -- no params given
procCmdMap "+p" prm st@(mp, _) = spawnObject st pos (Crop (cropFertility mp pos)) 30
    where pos = strToPos prm

-- (DEV MODE)
-- Spawn Water
procCmdMap "/+w" "" st = st   -- no params given
procCmdMap "/+w" prm (mp, res) = (changeTile mp pos tile', res)
    where 
        pos = strToPos prm
        (_, tobj, tunit, teff) = getTile mp pos
        tile' = (Water Fresh, tobj, tunit, teff)
-- catch-all
procCmdMap _ _ st = st


{-== Command Processing Utils ==-}
spawnObject :: GameState -> MapPos -> Object -> Int -> GameState
spawnObject (mp, res) pos obj cost = (changeTile mp pos tile', res - cost)
    where 
        (tb, _, tu, te) = getTile mp pos
        tile' = (tb, obj, tu, te)

-- " abc  " -> "abc"
trim :: String -> String
trim = unwords . words

-- "3, 5" -> (3,5)
strToPos :: String -> MapPos
strToPos s = (rdtr (head ar) :: Int, rdtr (ar !! 1) :: Int)
            where ar = splitOn "," s; rdtr = read . trim


{-== Crop Utils ==-}
cropFertility :: Map -> MapPos -> Int
cropFertility mp pos = countSurrTiles mp pos (hasTerrain (Water Fresh))


{-== Utils ==-}

bti :: Bool -> Int
bti True = 1
bti False = 0