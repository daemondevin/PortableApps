"""
Description: Sets bar lengths to length of bar 2 - Ensure bar markers are correctly positioned first
Category: Tempo
Shortcut:
Level: Beginners
Version: 1.06
Copyright:	(c) Hit'n'Mix Ltd 2019-2021
Author:		Chris Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

def ripscript():
	
	# Make rip the currently displayed Rip
	rip = ripx.current_view.rip
	
	# Check whether there is a Rip displayed
	if rip is None or len(rip.bars) < 3:
		ripx.pop_up("A Rip with at least 3 bars is required for this")
		return

	# Set each bar to the length of bar 2
	bar_length = rip.bar(2).duration
	for bar in rip.bars:
		
		if not ripx.interact("Equalizing Bar Lengths", bar.progress): return

		bar.stretch(duration=bar_length)
