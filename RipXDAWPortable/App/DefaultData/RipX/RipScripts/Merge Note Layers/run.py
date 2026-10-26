"""
Description: Merge amplitudes from all note layers to first layer
Category: Clean
Shortcut:
Level: Beginners
Version: 1.03
Copyright:	(c) Hit'n'Mix Ltd 2019-2021
Author:		Martin Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

def ripscript():
	
	# Make rip the currently displayed Rip
	rip = ripx.current_view.rip
	if rip is None or len(rip.selected_notes) == 0:
		ripx.pop_up("Merge Note Layers requires notes to be selected")
		return
		
	def harmonic_frequency(multiple, fundamental, inharmonicity):
		return fundamental * multiple * (1 + inharmonicity * ((multiple * multiple) - 1))
			
	# Note to update in Harmonic Editor?
	harmonic_editor_note = None
	if hasattr(ripx, "harmonic_editor"):
		harmonic_editor_note = ripx.harmonic_editor.note()

	# Go through selected notes, merging amplitudes from all layers to first layer
	# TODO: Could calculate average weighted frequencies
	for note in rip.selected_notes:
		if not ripx.interact("Merging Note Layers", note.progress): return
		if note.percussion: continue
		for harmonic in note.slices.harmonics:
			layer_1 = harmonic.layer(number=1)
			for layer_number in range(2, len(harmonic.layers) + 1):
				layer = harmonic.layer(number=layer_number)
				for slice_position in range(1, len(note.slices) + 1):
					layer_1.slice(position=slice_position).volume.amplitude += \
						layer.slice(position=slice_position).volume.amplitude
					layer.slice(position=slice_position).volume.amplitude = 0


		# Update note editor if it's running
		if note == harmonic_editor_note: ripx.harmonic_editor.refresh(note)
	