"""
Description: Removes artifacts from notes by recalculating frequencies for all harmonics
Category: Clean
Shortcut:
Level: Intermediate
Version: 1.02
Copyright:	(c) Hit'n'Mix Ltd 2019-2021
Author:		Martin Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

import math

def ripscript():
	
	# Make rip the currently displayed Rip
	rip = ripx.current_view.rip
	if rip is None or len(rip.selected_notes) == 0:
		ripx.pop_up("Clean Frequencies requires notes to be selected")
		return
		
	# Go through selected notes, recalculating frequencies for all harmonics
	for note in rip.selected_notes:
		if not ripx.interact("Cleaning Notes", note.progress): return
		if note.percussion: continue
			
		inharmonicity = note.inharmonicity
		
		for harmonic in note.slices.harmonics:
			
			multiple = harmonic.multiple
			frequency_multiplier = multiple * (1 + inharmonicity * ((multiple * multiple) - 1))
			
			for layer in harmonic.layers:			
				for slice in layer.slices:
					slice.pitch.frequency = note.slice(slice.position).pitch.frequency * frequency_multiplier
		
	# Play
	rip.selected_notes.play()
	