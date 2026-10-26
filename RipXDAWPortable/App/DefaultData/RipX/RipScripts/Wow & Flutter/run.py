"""
Description: Wow & Flutter gives a slow periodic variation in pitch, which can affect tape recorders
Category: Effects
Shortcut: 
Level: Intermediate
Version: 1.08
Copyright:	(c) Hit'n'Mix Ltd 2019-2021
Author:		Chris Dawe & Martin Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

import math

def ripscript():
	
	# Load settings and set defaults
	settings = Settings()
	settings.add("slider_1", 0.15)
	settings.add("slider_2", 1.0)

	# Add a window
	window = ripx.add_tk_window(sticky="nwe")
	pad_x = 6 * pixel_scale()
	pad_y = 4 * pixel_scale()
	
	# Add frame to place widgets in
	frame = window.add_label_frame(text="Choose Parameters")
	frame.grid(column=0, row=0, padx=12, pady=8)
	
	frame.add_label(text="Pitch variation (semitones):").grid(row=0, column=0, sticky=E, padx=pad_x, pady=pad_y*2)
	frame.add_label(text="Repeat every (seconds):").grid(row=2, column=0, sticky=E, padx=pad_x, pady=pad_y*2)
	
	def slider_1_updated(parameter_1_string):
		slider_1_label['text'] = "%.2f" % slider_1.get()
	frame.add_scale(from_=0.05, to=0.5, orient=HORIZONTAL, variable=slider_1, command=slider_1_updated, 
		length=140).grid(row=1, column=0, sticky="e", padx=pad_x, pady=pad_y)
	slider_1_label = frame.add_label(anchor="w", width=6)
	slider_1_label.grid(row=1, column=1, sticky="w", padx=pad_x, pady=pad_y)
	slider_1_label['text'] = "%.2f" % slider_1.get()
		
	def slider_2_updated(parameter_2_string):
		slider_2_label['text'] = "%.1f" % slider_2.get()
	frame.add_scale(from_=0.5, to=2.0, orient=HORIZONTAL, variable=slider_2, command=slider_2_updated,
		length=140).grid(row=3, column=0, sticky="e", padx=pad_x, pady=pad_y)
	slider_2_label = frame.add_label(anchor="w", width=6)
	slider_2_label.grid(row=3, column=1, sticky="w", padx=pad_x, pady=pad_y)
	slider_2_label['text'] = "%.1f" % slider_2.get()

	def apply_parameters(event: Event):

		# Show messages if rip not open or nothing selected (optional)
		rip = ripx.current_view.rip
		if rip is None:
			ripx.pop_up("Please select some notes first")
			return
		if len(rip.selected_notes) == 0:
			note_group = rip.selected_time_range.notes
		else:
			note_group = rip.selected_notes
		if len(note_group) == 0:
			ripx.pop_up("Please select some notes first")
			return
			
		# Apply Wow
		amplitude = slider_1.get()
		period = slider_2.get()
		for note in note_group:
			
			# Show a progress bar and exit if user presses Escape
			if not ripx.interact('Applying Wow & Flutter', note.progress):
				return
			
			if not note.percussion:
				for slice in note.slices:
					time = note.start + note.time_at(position=slice.position)
					slice.pitch += amplitude * math.sin(time*2*math.pi/period)
		
		# Close window when finished
		window.winfo_toplevel().destroy()
	
	# Add Apply button
	apply_button = window.add_button(text=" Apply ")
	apply_button.grid(column=0, row=1, padx=16, pady=pad_y, sticky=(E))
	apply_button.bind("<Button-1>", apply_parameters)
	
	# Bind window destroy event to the window_destroy function to
	# save settings when window closed
	def window_destroy(event):
		if event.widget != window: return
		settings.save()
	window.winfo_toplevel().bind("<Destroy>", window_destroy)
	
	# Cancel window
	def cancel(event: Event):
		window.winfo_toplevel().destroy()
		return "break"
	window.winfo_toplevel().bind("<Key-Escape>", cancel)
