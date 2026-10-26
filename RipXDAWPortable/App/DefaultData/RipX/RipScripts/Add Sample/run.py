"""
Description: Add sample from selection as a Sound Palette
Category: Tools
Shortcut:
Level: Beginners
Version: 1.06
Copyright:	(c) Hit'n'Mix Ltd 2019-2023
Author:		Martin Dawe
"""

import os
import platform
from tkinter import filedialog


def ripscript():

	def add_sound_from_note_group(note_group: NoteGroup, rip: Rip, category):
				
		## Remove layers less than this dB from peak average harmonic
		reduce_layers_db = -50

		## Maximum duration of sample in seconds
		max_sound_duration = 20

		if note_group is None or note_group.end < 0 or note_group.end == note_group.start:
			ripx.pop_up(message="Please select notes to add to the Sound panel")
			return
		
		# Create a new note group with notes we want
		# First add group for all notes in time region
		# If individual notes selected, not a time selection, so only keep selected note
		end_time = min(note_group.start + max_sound_duration, note_group.end) # Limit to maximum sample duration
		if len(rip.selected_notes) > 0:
			sound_group = rip.note_group(note_group.start, end_time).filter(add=in_note_group(rip.selected_notes))
		else:
			sound_group = rip.note_group(note_group.start, end_time)
		if sound_group is None or len(sound_group) == 0:
			ripx.pop_up(message="Please select notes to add to the Sound panel (2)")
			return

		# Copy notes to a temporary ripcut to merge harmonic notes and then group with percussive sounds
		temp_ripcut = rip.new_ripcut(name="Sound Panel Workspace")
		sound_group = sound_group.copy_to(time=0, rip=temp_ripcut)
		
		# Create group containing the pitched notes only
		pitch_group = sound_group.filter(omit=percussion)

		main_note = None
		if len(pitch_group) > 0:
			# Join pitched group into one note and add to sound group
			if reduce_layers_db: pitch_group.reduce_layers(to=reduce_layers_db) # Remove layers less than 50dB of peak average harmonic
			main_note = pitch_group.join_notes()
			sound_group.include(notes=main_note)
		else:
			# For pure percussion, set main note to first in sound group
			if reduce_layers_db: sound_group.reduce_layers(to=reduce_layers_db) # First remove layers less than 50dB of peak average harmonic
			for main_note in sound_group: break
			
		if main_note is None:
			ripx.pop_up(message="There was a problem adding the sample to the Sound panel, please try again")
			temp_ripcut.delete()
			return
				
		# Remove any note groupings as needs to be flat to be used as a sound
		sound_group.ungroup(flatten=True)
		
		# Group everything together
		sound_group.group()
		
		# Add to Sound Palette for track/instrument and rescan
		# Does palette exist for this Rip?
		palette = None
		# Restrict length of category so it doesn't get clipped, removing the end # and no longer being a Sound Palette
		if len(category) > 120: category = category[:120]
		palette_name = "#" + category + "#"
		for this_palette in ripx.riplist.rips:
			if this_palette.name == palette_name:
				palette = this_palette
				break
		if palette is None:
			palette = ripx.riplist.new_rip(palette_name)
		if palette is not None:
			# Does instrument exist?
			instrument = None
			for this_instrument in palette.ripcuts:
				if this_instrument.name == main_note.instrument:
					instrument = this_instrument
					break
			if instrument is None:
				instrument = palette.new_ripcut(main_note.instrument)
			if instrument is not None:
				# Does pitch already exist? (Or just whole instrument if percussion) If so, replace it
				for existing_note in instrument.notes:
					if existing_note.percussion == main_note.percussion and \
						(main_note.percussion or abs(existing_note.pitch.midi_number - main_note.pitch.midi_number) < 0.5):
						existing_grouped_percussion = existing_note.grouped_notes
						if existing_grouped_percussion is not None:
							existing_grouped_percussion.delete()
						existing_note.delete()
				# Copy to palette
				sound_group.copy_to(time=0, rip=instrument)
				# Save to disc
				instrument.save()
				# Show in panel
				instrument.show_in_panel()
				# Let user know
				ripx.pop_up(message="Added '" + main_note.instrument + "' to '" + category + "'")

		# Delete temporary ripcut
		temp_ripcut.delete()
		
	view = ripx.current_view
	if view.rip is not None:
		add_sound_from_note_group(view.rip.selected_notes, view.rip, view.rip.name)
	else:
		ripx.pop_up(message="Please select notes to add to the Sound panel")
