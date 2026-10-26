"""
Description: Infinity Scale applies the Shepard tone auditory illusion to notes
Category: Effects
Shortcut:
Level: Intermediate
Version: 1.06
Copyright:	(c) Hit'n'Mix Ltd 2019-2021
Author:		Martin Dawe and David Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

def ripscript():
	
	# Default values
	bars_per_octave_var = StringVar()
	bars_per_octave_var.set("2")
	direction_var = StringVar()
	direction_var.set("up")
	number_var = StringVar()
	number_var.set("triple")
	adjust_formants = False
	
	# Create window
	window = ripx.add_tk_window(sticky="nwe")
	pad_x = 6 * pixel_scale()
	pad_y = 4 * pixel_scale()
	frame = window.add_label_frame(text="Set octave change duration and direction")
	frame.grid(column=0, row=0, padx=pad_x, pady=pad_y)
	label = frame.add_label(text="Bars per octave")
	label.grid(row=0, column=0, padx=pad_x, pady=pad_y*2)
	bars_per_octave_combo = frame.add_combo_box(values=["1/32","1/16","1/8","1/4","1/2","1","1.5","2", "4", "8", "12", "16"],
		textvariable=bars_per_octave_var, state="readonly", justify="left", width=5)
	def bars_per_octave_combo_event(event: Event):
		bars_per_octave_combo.selection_clear() # To prevent selected text that shouldn't apply to read-only combo
	bars_per_octave_combo.bind("<<ComboboxSelected>>", bars_per_octave_combo_event)
	bars_per_octave_combo.grid(row=0, column=1, padx=pad_x, pady=pad_y*2)
	direction_up  = frame.add_radio_button(text="Up", variable=direction_var, value="up")
	direction_up.grid(column=0, row=1, padx=pad_x, pady=pad_y)
	direction_down  = frame.add_radio_button(text="Down", variable=direction_var, value="down")
	direction_down.grid(column=1, row=1, padx=pad_x, pady=pad_y)
	number_up  = frame.add_radio_button(text="Double notes", variable=number_var, value="double")
	number_up.grid(column=0, row=2, padx=pad_x, pady=pad_y)
	number_down  = frame.add_radio_button(text="Triple notes", variable=number_var, value="triple")
	number_down.grid(column=1, row=2, padx=pad_x, pady=pad_y*2)
	scale_button = frame.add_button(text="Scale Selected Notes")
	scale_button.grid(column=1, row=3, padx=pad_x, pady=pad_y*2)
	def scale(event: Event):
		
		# Make rip the currently displayed Rip
		rip = ripx.current_view.rip
		if rip is None:
			ripx.pop_up("Please open a rip and select notes to be scaled")
			return
		if len(rip.selected_notes) == 0:
			ripx.pop_up("Please select notes to be scaled")
			return
		
		# Get settings
		bars_per_octave = eval(bars_per_octave_var.get())
		if direction_var.get() == "up":
			direction = 12
		else:
			direction = -12

		apply_to_selection = True #len(rip.selected_notes) > 0
		
		triple_notes = number_var.get() == "triple"
		if triple_notes:
			loudness_adjustment = 0.5
		else:
			loudness_adjustment = 1.0
		
		# Start from first selected bar
		start_bar_index = rip.selected_bar_range.first
		while start_bar_index <= rip.selected_bar_range.last:
		
			bar_range_start = rip.bar(start_bar_index).start
			if bars_per_octave >= 1:
				octave_duration = rip.bar(start_bar_index + int(bars_per_octave) - 1).end - bar_range_start
			else:
				octave_duration = rip.bar(start_bar_index).duration * bars_per_octave
			octave_duration = max(octave_duration, 0.1)
			
			if not ripx.interact("Infinity Scaling",
				(bar_range_start - rip.selected_bar_range.start) / rip.selected_bar_range.duration):
				return
			
			# Process bars
			range_start = bar_range_start
			while range_start < rip.bar(start_bar_index).end - 0.001:
				
				# Make octave lower (if rising) or higher (if falling) copy
				# We move before copy to ensure note split at ends
				fade_in_notes = rip.note_group(range_start, min(rip.selected_bar_range.end, range_start + octave_duration)).filter(omit=percussion)
				if apply_to_selection:
					fade_in_notes = fade_in_notes.filter(add=in_note_group(rip.selected_notes))
				fade_in_notes.adjust_pitch(by=-direction)
				if triple_notes:
					original_notes = fade_in_notes.copy_to().adjust_pitch(by=direction)
					fade_out_notes = fade_in_notes.copy_to().adjust_pitch(by=direction * 2)
				else:
					fade_out_notes = fade_in_notes.copy_to().adjust_pitch(by=direction)
				
				# Fade-in notes
				for note in fade_in_notes:
					if adjust_formants: note.formant_pitch -= direction
					for slice in note.slices:
						range_position = (note.time_at(position=slice.position) + note.start - range_start) / octave_duration
						slice.pitch += direction * range_position
						if adjust_formants: slice.formant_pitch += direction * range_position
						slice.volume.loudness *= loudness_adjustment * range_position
						
				# Fade-out notes
				for note in fade_out_notes:
					if adjust_formants: note.formant_pitch += direction
					for slice in note.slices:
						range_position = (note.time_at(position=slice.position) + note.start - range_start) / octave_duration
						slice.pitch += direction * range_position
						if adjust_formants: slice.formant_pitch += direction * range_position
						slice.volume.loudness *= loudness_adjustment * (1 - range_position)
						
				if triple_notes:
					# Go through each note slice, and adjust pitch and loudness based upon position
					for note in original_notes:
						for slice in note.slices:
							range_position = (note.time_at(position=slice.position) + note.start - range_start) / octave_duration
							slice.pitch += direction * range_position
							if adjust_formants: slice.formant_pitch += direction * range_position
							slice.volume.loudness *= loudness_adjustment
						
				range_start += octave_duration
							
			# On to next set of bars
			start_bar_index += max(1, int(bars_per_octave))
					
		window.winfo_toplevel().destroy()
		
	scale_button.bind("<Button-1>", scale)
	
	# Cancel window
	def cancel(event: Event):
		window.winfo_toplevel().destroy()
		return "break"
	window.winfo_toplevel().bind("<Key-Escape>", cancel)

