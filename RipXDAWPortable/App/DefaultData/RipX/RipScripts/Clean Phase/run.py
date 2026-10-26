"""
Description: Removes artifacts from notes by recalculating phases for all harmonics
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
		ripx.pop_up("Clean Phase requires notes to be selected")
		return
		
	# Set to average phase rather than zero?
	average_phase = False
	
	# Clean frequency at same time?
	clean_frequency = False

	# Go through selected notes, recalculating phase for all harmonics
	for note in rip.selected_notes:
		if not ripx.interact("Cleaning Notes", note.progress): return
		if note.percussion: continue
			
		inharmonicity = note.inharmonicity
		
		slice_duration_degrees = note.slice_duration * 360
		for harmonic in note.slices.harmonics:
			
			multiple = harmonic.multiple
			frequency_multiplier = multiple * (1 + inharmonicity * ((multiple * multiple) - 1))
			
			for layer in harmonic.layers:
				
				if clean_frequency:
					for slice in layer.slices:
						slice.pitch.frequency = note.slice(slice.position).pitch.frequency * frequency_multiplier
		
				phase = [0, 0]
				if average_phase:
					# Find amplitude-weighted phase over layer
					total_loudness = 0
					slice_phase_adjustment = 0
					for slice in layer.slices:
						this_loudness = slice.volume.loudness
						total_loudness += this_loudness
						for channel in CHANNELS:
							phase[channel] += (slice.phase[channel] - slice_phase_adjustment) * this_loudness
						slice_phase_adjustment += slice.pitch.frequency * slice_duration_degrees
					for channel in CHANNELS:
						if total_loudness: phase[channel] /= total_loudness

				for slice in layer.slices:
					for channel in CHANNELS:
						slice.phase[channel] = phase[channel]
						# Phase for next slice
						phase[channel] += slice.pitch.frequency * slice_duration_degrees
	# Play
	rip.selected_notes.play()
	