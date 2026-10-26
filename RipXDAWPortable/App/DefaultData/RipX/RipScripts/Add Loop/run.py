"""
Description: Add loop from selection as a Sound Palette
Category: Tools
Shortcut:
Level: Beginners
Version: 1.01
Copyright:	(c) Hit'n'Mix Ltd 2019-2023
Author:		Martin Dawe
"""


def ripscript():

	def add_sound_from_note_group(note_group: NoteGroup, rip: Rip, category):
				
		## Maximum duration of loop in seconds
		max_sound_duration = 30

		if note_group is None or note_group.end < 0 or note_group.end == note_group.start:
			ripx.pop_up(message="Please select notes to add to the Loops panel")
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
			ripx.pop_up(message="Please select notes to add to the Loops panel (2)")
			return

		# Add to Sound Palette for track/instrument and rescan
		# Does palette exist for this Rip?
		palette = None
		# Restrict length of category so it doesn't get clipped, removing the end # and no longer being a Sound Palette
		if len(category) > 120: category = category[:120]
		palette_name = "]" + category + "["
		for this_palette in ripx.riplist.rips:
			if this_palette.name == palette_name:
				palette = this_palette
				break
		if palette is None:
			palette = ripx.riplist.new_rip(palette_name)
		if palette is not None:
			# Does instrument exist?
			instrument = palette.new_ripcut(rip.name)
			if instrument is None and len(palette.ripcuts) >= MAX_RIPCUTS_PER_RIP:
				ripx.pop_up(message="Maximum Loops per Folder is " + str(MAX_RIPCUTS_PER_RIP))
			if instrument is not None:
				# Clear any existing notes for importing loops, which only allow one note per instrument
				instrument.notes.delete()
				# Copy to palette
				sound_group.copy_to(time=0, rip=instrument)
				# Save to disc
				instrument.save()
				# Show in panel
				instrument.show_in_panel()
				# Let user know
				ripx.pop_up(message="Added '" + instrument.name + "' to '" + category + "'")
		
	view = ripx.current_view
	if view.rip is not None:
		add_sound_from_note_group(view.rip.selected_notes, view.rip, view.rip.name)
	else:
		ripx.pop_up(message="Please select notes to add to the Loops panel")
