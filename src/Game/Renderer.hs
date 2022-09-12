module Game.Renderer
( render )
where

import System.Console.ANSI
    ( clearScreen,
      setCursorPosition,
      setSGR,
      Color(Cyan, Yellow, Green, Black, White, Blue),
      ColorIntensity(Vivid, Dull),
      ConsoleLayer(Background, Foreground),
      SGR(Reset, SetColor) )
import Text.Printf
import Game.Data.Map ( MapTile, Map, Terrain (..), LandType (..), WaterType (..), Object (..), GameState, Effect (NoEffect))
import System.IO (stdout, hFlush)


{- Reset Color -}
resetColor :: IO ()
resetColor = setSGR [Reset]


{- Utils -}

clearTerminal :: IO ()
clearTerminal = do
    clearScreen
    setCursorPosition 0 0

itf :: Int -> Float
itf = fromIntegral

showf :: Int -> Int -> String
showf d = printf ("%." ++ show d ++ "f") . (/(10^d)) . itf

{- Game Renderer -}

render :: GameState -> IO ()
render (mp, res) = do
    clearTerminal
    renderMap mp
    renderText $ "resources: " ++ showf 1 res ++ "\n\n> "


{- Map rendering logic -}

-- Render Map
renderMap :: Map -> IO ()
renderMap mp = do
    renderMapLoop mp
    resetColor
    hFlush stdout


-- Recursive loop to render map
renderMapLoop :: Map -> IO ()

renderMapLoop [] = do                   -- when map is finished rendering
    putStrLn ""

renderMapLoop ([]:cls) = do             -- when one row of map is finished rendering
    putStrLn ""
    renderMap cls

renderMapLoop ((cl:clr):cls) = do       -- when actual tile rendering is happenging
    renderMapTile cl
    renderMap (clr:cls)


-- Render Map Tile
renderMapTile :: MapTile -> IO ()
renderMapTile tile = do
    setColor tile
    putStr $ strForTile tile


{- Other rendering logic -}

-- Render UI
renderText :: String -> IO ()
renderText s = do
    resetColor
    putStr s
    hFlush stdout


{- Color Mappings -}
setColor :: MapTile -> IO ()

-- Crop Field
setColor (Land Arable, Crop _, _, NoEffect) = do
    setSGR [SetColor Background Vivid Yellow]
    setSGR [SetColor Foreground Dull Black]
-- Arable Land
setColor (Land Arable, _, _, NoEffect) = do
    setSGR [SetColor Background Dull Green]
    setSGR [SetColor Foreground Dull Black]
-- Non Arable Land
setColor (Land NonArable, _, _, NoEffect) = do
    setSGR [SetColor Background Dull Yellow]
    setSGR [SetColor Foreground Dull White]
-- Fresh Water
setColor (Water Fresh, _, _, NoEffect) = do
    setSGR [SetColor Background Vivid Cyan]
    setSGR [SetColor Foreground Dull Cyan]
-- Fresh Water
setColor (Water Salty, _, _, NoEffect) = do
    setSGR [SetColor Background Vivid Blue]
    setSGR [SetColor Foreground Dull Blue]
-- catch-all
setColor _ = resetColor


{- Character Mappings -}
strForTile :: MapTile -> String

-- Crop
strForTile (_, Crop x, _, _)
        | x == 0 = ". "
        | x == 1 = ".."
        | x == 2 = ",,"
        | x == 3 = "::"
        | x == 4 = ";;"
        | x == 5 = "ii"
        | x == 6 = "ll"
        | x == 7 = "$$"
        | x == 8 = "##"
-- catch-all
strForTile _ = "  "