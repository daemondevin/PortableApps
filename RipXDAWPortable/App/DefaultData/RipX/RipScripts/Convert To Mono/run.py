"""
Description: Convert Rip To Mono
Category: Tools
Shortcut:
Level: Beginners
Version: 1.0
Copyright:	(c) Hit'n'Mix Ltd 2023
Author:		Martin Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

def ripscript():
	
	# Make rip the currently displayed Rip
	rip = ripx.current_view.rip
	
	# Check there is a Rip displayed
	if rip is None: return
	
	# For each note in the Rip's notes...
	for note in rip.notes:
	
		# Show a progress bar and exit if user presses Escape
		if not ripx.interact('Converting To Mono', note.progress):
			return
		
		# Convert each element of note to zero panning
		for slice in note.slices:
			slice.panning.angle = 0
			