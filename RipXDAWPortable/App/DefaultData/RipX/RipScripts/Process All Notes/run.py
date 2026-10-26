"""
Description: Do something with all notes in the currently displayed rip
Category: My RipScripts
Shortcut:
Level: Beginners
"""

def ripscript():
	
	# Make rip the currently displayed Rip
	rip = ripx.current_view.rip
	
	# Check there is a Rip displayed
	if rip is None: return
	
	# For each note in the Rip's notes...
	for note in rip.notes:
	
		# Show a progress bar and exit if user presses Escape
		if not ripx.interact('Processing All Notes', note.progress):
			return
		
		# Write code here, then press Ctrl+R to run on current Rip
		# Tip: Type 'note.' (no quotes) on the next line
		