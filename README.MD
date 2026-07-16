# Units

## What is Units?

* Units is a addon that tracks your total Temenos/Apollyon Units and shows the diff percentage until you're cap. 
* Automatically tracking your temp items for Code and floor data.
* It will warn you when you're getting close so you're not losing out on Units when you open a chest.
* It will warn you if you're nearing full inventory when you open a chest, that drops may be lost if you don't make room before leaving the area.

* Automatically detects Normal and Bonus chests.
* Normal chests remain tracked until the Bonus is found.
* Finding the Bonus starts a new rotation where all four chests are Possible Bonus again.
* Shows the Bonus Chance for each Possible Bonus chest and remembers the Last Bonus location.

## Notice on Packets

This  addon reads and sends a single client request packet (`0x115`) to refresh your Limbus Unit totals.

This is the same packet the game client sends when you open the currency menu - nothing is being modified or altered. 

## Commands

`//units show | hide` - Display | Hide the HUD

`//units mini | full` - Toggle between mini and full HUD


## Demo


### Full HUD

![Demo Image 1](demo1.png)


### Mini HUD

![Demo Image 2](demo2.png)
