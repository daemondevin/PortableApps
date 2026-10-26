"""
Description: Map Beats in Bars
Category: Mappers
Shortcut:
Level: Intermediate
Version: 1.14
Copyright:	(c) Hit'n'Mix Ltd 2019-2021
Author:		Martin Dawe & Chris Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

import bisect
import json

def ripscript():
	
	# Create window
	window = ripx.add_tk_window(sticky="nwe")
	pad_x = 6 * pixel_scale()
	pad_y = 4 * pixel_scale()
	
	# Settings
	beats = [2/3]
	
	# Load settings and set defaults
	settings = Settings()
	settings.add("user_beats", [2/3])
	settings.add("presets_combo_setting", "Swing")
	
	# Save settings
	def save_settings(event: Event):
		settings.save()
	window.winfo_toplevel().bind("<Destroy>", save_settings)

	# Message about ensuring barlines are set
	label = window.add_label(text="Important: Ensure barlines are correctly positioned in rip before use.\n"
		"Click and drag to add and reposition a beat marker below.\n"
		"Click and drag an existing beat marker far left or right to remove.")
	label.grid(row=0, column=0, columnspan=3, padx=pad_x, pady=pad_y)
						
	# Add Presets drop-down
	label = window.add_label(text="Presets:")
	label.grid(row=1, column=0, padx=pad_x, pady=pad_y, sticky=(E))	
	presets_combo = window.add_combo_box(values=["Swing", "Sway", "Custom"], state="readonly", textvariable=presets_combo_setting)
	presets_combo.grid(row=1, column=1, padx=pad_x, pady=pad_y, sticky=(W))
	def preset_selected(event: Event):
		presets_combo.selection_clear() # To prevent selected text that shouldn't apply to read-only combo
		nonlocal beats
		if presets_combo_setting.get() == "Swing":
			beats = [2/3]
		elif presets_combo_setting.get() == "Sway":
			beats = [4/12, 7/12, 9/12]
		elif presets_combo_setting.get() == "Custom":
			beats = user_beats
		update_beats()	
	presets_combo.bind("<<ComboboxSelected>>", preset_selected)
	
	# Canvas
	canvas = window.add_canvas(width=500*pixel_scale(), height=150*pixel_scale(), highlightthickness=0)
	canvas.grid(row=2, column=0, columnspan=3, padx=pad_x, pady=pad_y, sticky=(S,N,W,E))
	dragging_beat = -1
	def canvas_mouse_click(event: Event):
		nonlocal beats
		nonlocal dragging_beat
		# Are we near an existing beat to start a drag?
		beat_position = event.x / canvas.winfo_reqwidth()
		closest_beat = min(range(len(beats)), key=lambda i: abs(beats[i]-beat_position))
		closest_beat_x = beats[closest_beat] * canvas.winfo_reqwidth()
		if abs(closest_beat_x - event.x) < 4:
			dragging_beat = closest_beat
		else:
			# Add beat
			bisect.insort(beats, beat_position)
			dragging_beat = min(range(len(beats)), key=lambda i: abs(beats[i]-beat_position))
			update_beats(dragging_beat, True)
			
	def canvas_mouse_release(event: Event):
		nonlocal dragging_beat
		# If we end up right next to another then delete
		if dragging_beat > 0:
			previous_beat_x = beats[dragging_beat - 1] * canvas.winfo_reqwidth()
		else:
			previous_beat_x = 1/64 * canvas.winfo_reqwidth()
		if dragging_beat < len(beats) - 1:
			next_beat_x = beats[dragging_beat + 1] * canvas.winfo_reqwidth()
		else:
			next_beat_x = 63/64 * canvas.winfo_reqwidth()
		dragging_beat_x = beats[dragging_beat] * canvas.winfo_reqwidth()
		if len(beats) > 1 and (abs(previous_beat_x - dragging_beat_x) < 18 or abs(next_beat_x - dragging_beat_x) < 18):
			beats.pop(dragging_beat)
			update_beats()
		else:
			user_beats = beats
			presets_combo_setting.set("Custom")		
		dragging_beat = -1

	def canvas_motion(event: Event):
		nonlocal beats
		beat_position = event.x / canvas.winfo_reqwidth()
		if dragging_beat >= 0:
			# Restrict to previous/next beats
			if dragging_beat > 0:
				previous_beat = beats[dragging_beat - 1] + 1/64
			else:
				previous_beat = 1/64
			if dragging_beat < len(beats) - 1:
				next_beat = beats[dragging_beat + 1] - 1/64
			else:
				next_beat = 63/64
			beat_position = max(min(beat_position, next_beat), previous_beat)
			beats[dragging_beat] = beat_position
			dragging_beat_x = beats[dragging_beat] * canvas.winfo_reqwidth()
			if len(beats) > 1 and (abs(previous_beat * canvas.winfo_reqwidth() - dragging_beat_x) < 8 or \
				abs(next_beat * canvas.winfo_reqwidth() - dragging_beat_x) < 8):
				update_beats(dragging_beat, False)
			else:
				update_beats(dragging_beat, True)
		else:
			closest_beat = min(range(len(beats)), key=lambda i: abs(beats[i]-beat_position))
			closest_beat_x = beats[closest_beat] * canvas.winfo_reqwidth()
			if abs(closest_beat_x - event.x) < 4:
				update_beats(closest_beat, True) # Redraws highlighted
			else:
				update_beats()
				
	canvas.bind("<Button-1>", canvas_mouse_click)
	canvas.bind("<Motion>", canvas_motion)
	canvas.bind("<ButtonRelease-1>", canvas_mouse_release)
	
	# Add Selection/Whole Rip radio icon
	
	# Apply button
	apply_button = window.add_button(text="Apply To All Bars")
	apply_button.grid(row=3, column=2, padx=pad_x, pady=pad_y, sticky=(E))
	def apply_clicked(event: Event):
		# Perform the mapping
		rip = ripx.current_view.rip
		if rip is None:
			ripx.pop_up("Beat Mapper requires a rip to be loaded")
			return
		for bar in rip.bars:
			if not ripx.interact("Mapping Beats", bar.progress): return
			bar.map_beats(to=beats)
	apply_button.bind("<Button-1>", apply_clicked)
	apply_selected_button = window.add_button(text="Apply To Selected Bars")
	apply_selected_button.grid(row=3, column=0, padx=pad_x, pady=pad_y, sticky=(W))
	def apply_selected_clicked(event: Event):
		# Perform the mapping
		rip = ripx.current_view.rip
		if rip is not None:
			for bar in rip.selected_bar_range:
				if not ripx.interact("Mapping Beats", bar.progress): return
				bar.map_beats(to=beats)
	apply_selected_button.bind("<Button-1>", apply_selected_clicked)
		
	def update_beats(in_beat_index=-1, highlight_hide=False):
		
		# Clear existing objects
		canvas.delete("all")
		canvas.create_rectangle(0, 0, canvas.winfo_reqwidth(), canvas.winfo_reqheight(), fill="#000000")
		
		# Colour
		r = 0x45
		g = 0x61
		b = 0x79
		tk_rgb = "#%02x%02x%02x" % (r, g, b)
		tk_rgb_hide = "#%02x%02x%02x" % (int(r / 4), int(g / 4), int(b / 4) )
		tk_rgb_hl = "#%02x%02x%02x" % (0xff, 0xff, 0xff)

		# Add lines
		y1 = canvas.winfo_reqheight()
		nsubbeats = 4
		lastx = 0
		for beat in beats:
			x = beat * canvas.winfo_reqwidth()
			# Main beat
			if in_beat_index >= 0 and beats[in_beat_index] == beat:
				if highlight_hide:
					canvas.create_line(x, 0, x, y1, fill=tk_rgb_hl)
				else:
					canvas.create_line(x, 0, x, y1, fill=tk_rgb_hide)					
			else:
				canvas.create_line(x, 0, x, y1, fill=tk_rgb)
			# Sub beats before
			for subbeat in range(1, nsubbeats):
				sx = lastx + (x - lastx) * subbeat / nsubbeats
				canvas.create_line(sx, 0, sx, y1, fill=tk_rgb, dash=(4, 4))
			lastx = x
		# Sub beats after
		for subbeat in range(1, nsubbeats):
			sx = lastx + (canvas.winfo_reqwidth() - lastx) * subbeat / nsubbeats
			canvas.create_line(sx, 0, sx, y1, fill=tk_rgb, dash=(4, 4))
	
	# Draw canvas for beats
	preset_selected(None)

	# Cancel window
	def cancel(event: Event):
		window.winfo_toplevel().destroy()
		return "break"
	window.winfo_toplevel().bind("<Key-Escape>", cancel)
