"""
Description: Note Harmonic Editor
Category: 
Shortcut: Ctrl+T
Level: Advanced
Version: 2.04
Copyright:	(c) Hit'n'Mix Ltd 2019-2023
Author:		Martin Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

import time
import math
import platform
from PIL import Image, ImageDraw, ImageTk
from tkinter import messagebox
import tkinter.font as TkFont
import os


selection_mode = 0
palette_mode = -1 # Disabled
erase_mode = 1#2
adjust_level_mode = 2#3
remove_spikes_mode = 3#4
remove_harmonics_mode = 4#5
blend_mode = 5#6
clone_from_slice_mode = 6#7
increase_to_slice_mode = 7#8
reduce_to_slice_mode = 8#9
add_slice_mode = 9#10
subtract_slice_mode = 10#11
remove_timbre_mode = 12 # Disabled
keep_timbre_mode = 13 # Disabled
number_of_tools = 11#2

harmonic_editor_tools = [ \
			[selection_mode, "Select / Edit / Mask", "selection_tool_x2.png"],
			#[palette_mode, "Paint Sound", "paint_tool_x2.png"],
			[erase_mode, "Erase Sound", "erase_tool_x2.png"],
			[adjust_level_mode, "Adjust Level", "adjust_level_tool_x2.png"],
			[remove_spikes_mode, "Remove Noise", "remove_spikes_tool_x2.png"],
			[remove_harmonics_mode, "Reduce Loud Harmonics", "remove_harmonics_tool_x2.png"],
			[blend_mode, "Smooth Harmonics", "blend_tool_x2.png"],
			[clone_from_slice_mode, "Clone From Time Slice", "clone_from_slice_tool_x2.png"],
			[increase_to_slice_mode, "Increase To Time Slice", "increase_to_slice_tool_x2.png"],
			[reduce_to_slice_mode, "Reduce To Time Slice", "reduce_to_slice_tool_x2.png"],
			[add_slice_mode, "Increase By Time Slice", "add_slice_tool_x2.png"],
			[subtract_slice_mode, "Reduce By Time Slice", "subtract_slice_tool_x2.png"],
#			[remove_timbre_mode, "Remove Sound Of Another Note", "remove_timbre_tool_x2.png"],
#			[keep_timbre_mode, "Keep Sound Of Another Note", "keep_timbre_tool_x2.png"]
			]
			

harmonic_editor_tools_tips = [ \
	"Click & drag to select region to play, edit & mask (Hold down Alt from other tools)  (Press 1)",
	#"Click & drag to paint selected Sound from main toolbar, using the settings below  (Press 2)",
	"Click & drag to erase sound, using the settings below  (Press 2)",
	"Click & drag to adjust sound level, using the settings below  (Press 3)",
	"Click & drag to remove unwanted clicks and percussive sounds (Set Brush longer than noise)  (Press 4)",
	"Click & drag to quieten harmonics that stick out  (Press 5)",
	"Click & drag to smooth individual harmonic levels out, using the settings below (Press 6)",
	"Ctrl+click a time slice, then click & drag to clone from that region  (Press 7)",
	"Ctrl+click a time slice, then click & drag to increase the level to it  (Press 8)",
	"Ctrl+click a time slice, then click & drag to reduce the level to it  (Press 9)",
	"Ctrl+click a time slice, then click & drag to increase the level by it  (Press 0)",
	"Ctrl+click a time slice, then click & drag to reduce the level by it  (Shift-1)",
#	"Ctrl+click a note, then click & drag to remove its sound (Shift-3)",
#	"Ctrl+click a note, then click & drag to remove everything but its sound (Shift-4)"
	]

min_slice_width = 6
min_harmonic_height = 6

def ripscript():
	
	# Create class to provide update functionality from other RipScripts
	class HarmonicEditor():
		def __init__(self):
			return
		def note(self):
			# Return note currently being edited
			if not ripx.ripscript_running("Harmonic Editor"): return None
			if edit_note is not None and not edit_note: return None
			return edit_note
		def refresh(self, note=None):
			# Refresh display for note if it is the current one being edited
			if not ripx.ripscript_running("Harmonic Editor"): return
			nonlocal edit_note, anchor_slice
			if note is None: note = edit_note
			if edit_note is not None and edit_note and note is not None and note and edit_note == note:
				anchor_slice = 0
				clear_selection()
				canvas.xview('moveto', 0)
				canvas_hscale_region.xview('moveto', 0)
				update_layers()
				show_note(edit_note, None)
			elif edit_note is None or not edit_note:
				show_note(None, None)
				
	sp = HarmonicEditor()
	# Store so accessible by other RipScripts
	ripx.harmonic_editor = sp
		
	# Load settings and set defaults
	settings = Settings()
	def current_editmode(index=-1):
		# Get mode, adjusted for divider lines
		if index < 0: index = tool_setting.get()
		return index
		
	settings.add("tool_setting", selection_mode)
	#tool_setting.set(selection_mode) # Always reset to pointer now so don't accidentally edit notes with another tool
	if tool_setting.get() >= number_of_tools: tool_setting.set(selection_mode)
	settings.add("canvas_width", 640*pixel_scale())
	settings.add("canvas_height", 360*pixel_scale())
	settings.add("remove_to_other", 0)
	settings.add("time_scale", 1.0)
	settings.add("contrast", 4.0)
	settings.add("replace", 1.0)
	settings.add("level", 0.0)
	settings.add("sellevel", 0.0)
	settings.add("harmonics_setting", "All")
	settings.add("brush_duration", 0.2)
	settings.add("show_adjusted", 1)
	harmonics = range(1, MAX_HARMONIC_MULTIPLE + 1)

	# Create window with canvas
	window = ripx.add_tk_window(sticky="nwe", resizable=True)
	pad_x = 6 * pixel_scale()
	pad_y = 4 * pixel_scale()
	show_layers = False
	
	# Load icons
	global play_image, refresh_image, reset_image, stop_image, info_image, cut_image, copy_image, paste_image
	global cut_disabled_image, copy_disabled_image, paste_disabled_image, show_adjusted_image, show_adjusted_on_image
	def get_image(filename):
		im = Image.open(ripscript_path(filename))
		scale = pixel_scale() / 3 # We are provided x2 sized bitmaps
		im = im.resize((int(im.width * scale), int(im.height * scale)), Image.ANTIALIAS)
		return ImageTk.PhotoImage(im)
	play_image=get_image("play_x2.png")
	stop_image=get_image("stop_x2.png")
	refresh_image=get_image("refresh_x2.png")
	reset_image=get_image("reset_x2.png")
	info_image=get_image("info_x2.png")
	cut_image=get_image("cut_x2.png")
	copy_image=get_image("copy_x2.png")
	paste_image=get_image("paste_x2.png")
	cut_disabled_image=get_image("cut_disabled_x2.png")
	copy_disabled_image=get_image("copy_disabled_x2.png")
	paste_disabled_image=get_image("paste_disabled_x2.png")
	show_adjusted_image=get_image("show_adjusted_x2.png")
	show_adjusted_on_image=get_image("show_adjusted_on_x2.png")

	note_image = None
	canvas_image = None
	timbre_note: Note = None
	transfer_note: Note = None
	anchor_slice = 0
	edit_anchor_slice = 0
	edit_anchor_slice_start = edit_anchor_slice_end = 0
	options_frame = window.add_frame()
	options_frame.grid(row=0, column=0, columnspan=2, padx=pad_x, pady=0, sticky="we")
	
	## Tools
	# Create icon bar for quick selection of tools
	# Load button images into global variables to ensure not garbage collected and removed
	global photos
	photos = []
	def add_image(filename):
		global photos
		im = Image.open(ripscript_path(filename))
		scale = pixel_scale() * 0.4 # We are provided x2 sized bitmaps
		im = im.resize((int(im.width * scale), int(im.height * scale)), Image.ANTIALIAS)
		photos.append(ImageTk.PhotoImage(im))
	def toolbar_button_clicked():
		# Check not running Hit'n'Mix First
		tool = tool_setting.get()
		if tool >= 0: set_tool(harmonic_editor_tools[tool][0])
	for tool in range(0, number_of_tools):
		add_image(harmonic_editor_tools[tool][2])
		if platform.system() == "Darwin": # Mac OS X
			tooltip = harmonic_editor_tools_tips[tool].replace("Ctrl+", "\u2318-")
			tooltip = harmonic_editor_tools_tips[tool].replace("Alt", "\u2325")
		else:
			tooltip = harmonic_editor_tools_tips[tool]
		options_frame.add_radio_button(image=photos[tool], style='Toolbar.TRadiobutton',
			variable=tool_setting, value=tool, command=toolbar_button_clicked,
			tooltip=harmonic_editor_tools[tool][1] + " Tool: \n\n" + tooltip).grid(row=int(tool/number_of_tools), column=int(tool%number_of_tools)+2,
			pady=6*pixel_scale())

	def set_cursor():
		# Set cursor
		cursor = "arrow" #"none" # NB "none" caused no cursor to be displayed when left tkinter window too
		mode = current_editmode()
		if selecting_region or mode == selection_mode:
			cursor = "arrow"
		else:
			if mode >= clone_from_slice_mode and mode <= add_slice_mode:
				if not anchor_slice: cursor = "arrow"
			elif in_timbre_mode():
				if not note_exists(timbre_note): cursor = "arrow"
		canvas.config(cursor=cursor)
		# And for hscale time bar
		if note_exists(edit_note):
			# To set the cursor we need the working directory to be the RipScript folder
			existing_path = os.getcwd()
			os.chdir(ripscript_path(path=""))
			if pixel_scale() == 1 or platform.system() == "Darwin": # macOS tkinter doesn't support the retina cursor currently
				canvas_hscale_region.config(cursor='@ptr_zoom_time.cur')
			else:
				canvas_hscale_region.config(cursor='@ptr_zoom_time_x2.cur')
			os.chdir(existing_path)
		else:
			canvas_hscale_region.config(cursor='arrow')

	def set_tool(tool=None):
		nonlocal anchor_slice
		if tool is not None: tool_setting.set(tool)
		mode = current_editmode()
		update_slice_anchor()
		update_timbre_text()
		update_timbre_spotlight()
		if platform.system() == "Darwin": # Mac OS X
			instructions = harmonic_editor_tools_tips[mode].replace("Ctrl+", "\u2318-")
			instructions = harmonic_editor_tools_tips[mode].replace("Alt", "\u2325")
		else:
			instructions = harmonic_editor_tools_tips[mode]
		mode_instructions.config(text=instructions)
		update_transfer_button()
		# Replace/Level slider boxes present
		if mode == selection_mode:
			# Just sellevel slider, buttons (cut, copy, paste) and some instructions (e.g. to hold down Alt in other modes)
			brush_frame.grid_remove()
			level_frame.grid_remove()
			replace_frame.grid_remove()
			harmonics_frame.grid_remove()
			selection_frame.grid(row=0, rowspan=2, column=4, sticky="w")
			update_selection_level()
		elif mode == palette_mode or mode == erase_mode or mode == blend_mode:
			# Have Replace slider
			level_frame.grid_remove()
			selection_frame.grid_remove()
			brush_frame.grid(row=0, rowspan=2, column=1, sticky="w")
			replace_frame.grid(row=0, rowspan=2, column=4, sticky="w")
			harmonics_frame.grid(row=0, rowspan=2, column=5, sticky="w")
			if mode == palette_mode:
				replace_text_label['text'] = "Replace"
			elif mode == erase_mode:
				replace_text_label['text'] = "Amount"
			elif mode == blend_mode:
				replace_text_label['text'] = "Strength"
		elif mode == remove_spikes_mode or mode == remove_harmonics_mode:
			# Neither slider
			level_frame.grid_remove()
			selection_frame.grid_remove()
			replace_frame.grid_remove()
			brush_frame.grid(row=0, rowspan=2, column=1, sticky="w")
			harmonics_frame.grid(row=0, rowspan=2, column=5, sticky="w")
		else:
			# Level slider
			brush_frame.grid(row=0, rowspan=2, column=1, sticky="w")
			level_frame.grid(row=0, rowspan=2, column=4, sticky="w")
			harmonics_frame.grid(row=0, rowspan=2, column=5, sticky="w")
			selection_frame.grid_remove()
			replace_frame.grid_remove()
		set_cursor()
							
	#nr_button = window.add_button(text=" Noise Removal... ",
	#	tooltip="Click here to open the Noise Removal tool to quickly remove foreground or background noise")
	#nr_button.grid(row=0, column=1, padx=pad_x, pady=pad_y, sticky="e")
	#def noise_removal(event: Event):
	#	ripx.run_ripscript(name="Noise Removal")	
	#nr_button.bind("<Button-1>", noise_removal)
	
	
	# Play/refresh buttons
	button_frame = window.add_frame()
	button_frame.grid(row=0, column=1, sticky="e", padx=pad_x)

	button_frame.add_separator(orient=VERTICAL).grid(row=0, column=0, sticky="ns", padx=3*pixel_scale())	
	play_button = button_frame.add_button(image=play_image, style='Toolbar.TButton',
		tooltip="Play")
	play_button.grid(row=0, column=2, padx=2*pixel_scale(), pady=0, sticky="e")
	playback_rip: Rip = None
	playback_starttime = 0
	def play_update(event: Event=None):
		nonlocal playback_rip, playback_starttime
		# Still playing?
		# Remove cursor
		canvas.delete("playback_cursor")	
		playback_time = None
		if playback_rip and playback_rip is not None: playback_time = playback_rip.playback_time
		if playback_time is not None and note_exists(edit_note):
			# Update cursor
			tk_rgb_hl = "#%02x%02x%02x" % (0xff, 0xff, 0xff)	# Level 0 - bar level
			x = int((playback_time - playback_starttime) / edit_note.slice_duration + 0.5) * slice_width
			if x >= 0 and x < canvas.winfo_reqwidth() + canvas_hscoll_max:
				y0 = 0
				y1 = canvas.winfo_reqheight()
				if region_selected and selection_slice_1 != 0:
					y0 = canvas.winfo_reqheight() - (min(selection_harmonic_0, selection_harmonic_1) - 1) * harmonic_height - 1
					y1 = canvas.winfo_reqheight() - (max(selection_harmonic_0, selection_harmonic_1)) * harmonic_height - 0
				canvas.create_line(x, y0, x, y1, fill=tk_rgb_hl, tags="playback_cursor")	
			window.after(40, play_update)
		else:
			# Stop
			play_button.config(image=play_image)
			
	def play(event: Event=None):
		nonlocal edit_note, anchor_slice, playback_rip, playback_starttime
		# Already playing whole note in rip?
		if event is not None and playback_rip is not None and playback_rip and playback_rip.playback_time is not None:
			playback_rip.stop()
			return "break"
		elif note_exists(edit_note):
			if selection_slice_range() is not None:
				play_selection()
			else:
				edit_note.play()
				playback_rip = edit_rip
				playback_starttime = edit_note.start
			play_update()
			window.after(40, play_update)
			play_button.config(image=stop_image)
		return "break"
			
	def selection_note(ripcut: Rip):
		# Create a note representing the selected audio in the given rip(cut)
		selected_slice_range = selection_slice_range()
		selection_note = ripcut.add_note(at=0.0, percussion=edit_note.percussion)
		selected_slice_range.copy_to(note=selection_note)
		play_layer = visible_layer()
		if play_layer != 0: # Not all
			# Remove all but visible_layer
			## TODO: Update so can specify layers when creating slice range so not necessary
			for harmonic in selection_note.slices.harmonics:
				for layer in harmonic.layers:
					if layer.number != play_layer:
						layer.volume.amplitude = 0
		return selection_note

	def play_selection():
		nonlocal playback_rip, playback_starttime
		# Don't play if already playing current rip (as may be looping)
		if playback_rip is not None and playback_rip and playback_rip == edit_rip and \
			playback_rip.playback_time is not None:
			return "break"
		# Play selection
		# Create temporary RipCut with an empty note, then copy the slice/harmonic range to it and play it
		selected_slice_range = selection_slice_range()
		if selected_slice_range is not None:
			playback_ripcut = edit_rip.new_ripcut(name="[Harmonic Editor Playback]")
			playback_note = selection_note(playback_ripcut)
			playback_note.play()
			playback_starttime = edit_note.start - selected_slice_range.start
			playback_rip = playback_ripcut
			playback_ripcut.remove()

	play_button.bind("<Button-1>", play)
	
	# Reset edits
	reset_button = button_frame.add_button(image=reset_image, style='Toolbar.TButton',
		tooltip="Reset all edits made to note since opened in Harmonic Editor")
	reset_button.grid(row=0, column=3, padx=0, pady=0, sticky="e")
	def reset_edits(event: Event):
		nonlocal edit_note, reset_note
		if note_exists(reset_note) and note_exists(edit_note):
			# Copy contents of reset_note to edit_note
			reset_note.slices.copy_to(note=edit_note, time=0.0)
			edit_note.slice_range(reset_note.duration).delete()
			show_note(edit_note, None)
	reset_button.bind("<Button-1>", reset_edits)

	button_frame.add_separator(orient=VERTICAL).grid(row=0, column=4, sticky="ns", padx=pad_x)	

	# Show Adjusted amplitudes
	show_adjusted_button = button_frame.add_button(image=show_adjusted_image, style='Toolbar.TButton',
		tooltip="Show with effects, repairs & other live adjustments applied")
	show_adjusted_button.grid(row=0, column=5, padx=0, pady=0, sticky="e")
	def show_adjusted_levels(event: Event):
		if show_adjusted.get() == 0:
			show_adjusted.set(1)
			show_adjusted_button.config(image=show_adjusted_on_image)
		else:
			show_adjusted.set(0)
			show_adjusted_button.config(image=show_adjusted_image)
		show_note(edit_note, None)
	show_adjusted_button.bind("<Button-1>", show_adjusted_levels)
	if show_adjusted.get() == 1:
		show_adjusted_button.config(image=show_adjusted_on_image)
	else:
		show_adjusted_button.config(image=show_adjusted_image)

	# Refresh display
	refresh_button = button_frame.add_button(image=refresh_image, style='Toolbar.TButton',
		tooltip="Refresh display if you have edited the note with another tool")
	refresh_button.grid(row=0, column=6, padx=2*pixel_scale(), pady=0, sticky="e")
	def refresh_canvas(event: Event):
		nonlocal edit_note, anchor_slice
		if note_exists(edit_note):
			anchor_slice = 0
			#clear_selection()
			canvas.xview('moveto', 0)
			canvas_hscale_region.xview('moveto', 0)
			update_layers()
			show_note(edit_note, None)
	refresh_button.bind("<Button-1>", refresh_canvas)

	# Contrast
	label = button_frame.add_label(text="Contrast ", anchor="e")
	label.grid(row=0, column=7, sticky="e", padx=2*pixel_scale())
	current_contrast = contrast.get()
	def contrast_changed(contrast_str):
		nonlocal current_contrast
		to_contrast = contrast.get()
		to_contrast = (int)(to_contrast * 128) / 128
		if to_contrast == current_contrast: return
		current_contrast = to_contrast
		canvas_redraw()
	contrast_slider = button_frame.add_scale(from_=1, to=16, orient=HORIZONTAL,
		variable=contrast, command=contrast_changed, length=60*pixel_scale(),
		tooltip="Drag slider to adjust the note level contrast")
	contrast_slider.grid(row=0, column=8, sticky="e")	
	
	window.add_separator(orient=HORIZONTAL).grid(row=2, column=0, columnspan=2, sticky="we")
			
	def note_exists(note):
		if note is not None:
			if note:
				return True
			else:
				note = None
				return False
		else:
			return False
	
	def db_adjustment():
		# Convert replace value to existing note volume adjustment
		return loudness(1.0 - replace.get()).db

	# Get spotlight info
	def get_spotlight_info():
		using_palette = False
		mode = current_editmode()
		if mode == palette_mode or mode == erase_mode or \
			mode == adjust_level_mode or in_timbre_mode():
			using_palette = True
		this_duration, fade_in, fade_out = get_brush_duration_and_fade()
		if using_palette:
			this_fade_in = min(this_duration / 2, fade_in)
			this_fade_out = min(this_duration / 2, fade_out)
		else:
			this_fade_in = this_fade_out = 0		
		return using_palette, this_duration, this_fade_in, this_fade_out

	# Draw spotlight
	def draw_spotlight(this_harmonic, time):
		mode = current_editmode()
		if mode != selection_mode and edit_note is not None and edit_note:
			# Draw spotlight
			canvas.delete("spotlight")
						
			# Slice modes require slice to be set
			if in_slice_mode() and (anchor_slice < 1 or anchor_slice > edit_note.number_of_slices): return
						
			# Timbre modes require timbre note to be set
			if in_timbre_mode() and not note_exists(timbre_note):
				view.spotlight(source_note=None, source_time=-1)
				update_timbre_text()
				return
			
			# Get spotlight size, fade
			using_palette, this_duration, this_fade_in, this_fade_out = get_spotlight_info()
			edit_time_start = max(0, time - this_duration / 2)
			# Adjust to slice
			edit_time_start = edit_note.time_at(edit_note.slice_at(edit_time_start))
			edit_time_end = edit_time_start + this_duration + min(0, time - this_duration / 2 + edit_note.slice_duration / 4)
			edit_time_start_fade = max(0, time - this_duration / 2 + this_fade_in)
			edit_time_end_fade = edit_time_end - this_fade_out
			edit_slice_start = edit_note.slice_at(edit_time_start)
			edit_slice_end = edit_note.slice_at(edit_time_end)
			edit_slice_start_fade = edit_note.slice_at(edit_time_start_fade)
			edit_slice_end_fade = edit_note.slice_at(edit_time_end_fade)
			pixel_start = (edit_slice_start - 1) * slice_width
			pixel_end = (edit_slice_end - 1) * slice_width
			pixel_start_fade = (edit_slice_start_fade - 1) * slice_width
			pixel_end_fade = (edit_slice_end_fade- 1) * slice_width
			pixel_top = canvas.winfo_reqheight() - (this_harmonic - 1) * harmonic_height - 1
			pixel_bot = pixel_top - harmonic_height + 1
			
			# Central full effect region
			if using_palette or in_slice_mode():
				level = db(level_for_mode()).loudness
				tk_rgb = loudness_colour(level / 8)
			else:
				tk_rgb = "#a0a0a0"
			canvas_spotlight = canvas.create_rectangle(
				pixel_start_fade,
				pixel_top - 1,
				pixel_end_fade - 1,
				pixel_bot,
				fill=tk_rgb, outline=tk_rgb, tags="spotlight")
			
			if using_palette:
				# Fade in/out edges
				for slice in range(edit_slice_start, edit_slice_start_fade):
					tk_rgb = loudness_colour(level / 8 * (slice - edit_slice_start + 1) / (edit_slice_start_fade - edit_slice_start + 1))
					x1 = (slice - 1) * slice_width
					x2 = (slice + 1 - 1) * slice_width
					canvas_spotlight_fade_in = canvas.create_rectangle(
						x1,
						pixel_top - 1,
						x2 - 1,
						pixel_bot,
						fill=tk_rgb, outline=tk_rgb, tags="spotlight")
				for slice in range(edit_slice_end_fade, edit_slice_end):
					tk_rgb = loudness_colour(level / 8 * (edit_slice_end - slice) / (edit_slice_end - edit_slice_end_fade + 1))
					x1 = (slice - 1) * slice_width
					x2 = (slice + 1 - 1) * slice_width
					canvas_spotlight_fade_in = canvas.create_rectangle(
						x1,
						pixel_top - 1,
						x2 - 1,
						pixel_bot,
						fill=tk_rgb, outline=tk_rgb, tags="spotlight")
	# Draw spotlight for changing brush duration
	def draw_brush_duration_spotlight():
		if note_exists(edit_note) and slice_width > 0:
			this_duration, this_fade_in, this_fade_out = get_brush_duration_and_fade()
			hscroll_slices = 1.0 + canvas_hscroll.get()[0] * canvas_hscoll_max / slice_width
			draw_spotlight(MAX_HARMONIC_MULTIPLE, hscroll_slices * edit_note.slice_duration + this_duration / 2)

	## Settings frame
	frame = window.add_frame()
	frame.grid(row=3, column=0, columnspan=2, padx=pad_x, pady=pad_y, sticky="we")

	# Duration slider
	brush_frame = frame.add_frame()
	label = brush_frame.add_label(text="Brush", anchor="w")
	label.grid(row=1, column=0, padx=pad_x, pady=0, sticky="w")
	def brush_duration_changed(loudness_str):
		brush_duration_label['text'] = " %.2f s" % brush_duration.get()
		draw_brush_duration_spotlight()
	brush_duration_scale = brush_frame.add_scale(from_=0.01, to=1.0, orient=HORIZONTAL,
		variable=brush_duration, command=brush_duration_changed, length=100*pixel_scale(),
		tooltip="Drag slider to adjust duration of brush")
	brush_duration_scale.grid(row=0, column=0, columnspan=2, padx=pad_x, pady=pad_y, sticky="w")
	in_brush_duration = False
	def brush_duration_enter(event: Event):
		nonlocal in_brush_duration
		in_brush_duration = True
		draw_brush_duration_spotlight()
	def brush_duration_leave(event: Event):
		nonlocal in_brush_duration
		in_brush_duration = False
		canvas.delete("spotlight")
	brush_duration_scale.bind("<Enter>", brush_duration_enter)
	brush_duration_scale.bind("<Leave>", brush_duration_leave)
	brush_duration_label = brush_frame.add_label(anchor="e", width=6, style='Value.TLabel')
	brush_duration_label.grid(row=1, column=1, padx=pad_x, pady=0, sticky="e")
	brush_duration_label['text'] = " %.2f s" % brush_duration.get()
		
	# Replace slider
	replace_frame = frame.add_frame()
	replace_frame.add_separator(orient=VERTICAL).grid(row=0, rowspan=2, column=3, sticky="ns", padx=pad_x)	
	replace_text_label = replace_frame.add_label(text="Replace", anchor="w")
	replace_text_label.grid(row=1, column=4, padx=pad_x, pady=0, sticky="w")
	def replace_changed(loudness_str):
		replace_label['text'] = " %.0f%%" % (replace.get() * 100)
	replace_scale = replace_frame.add_scale(from_=0.0, to=1.0, orient=HORIZONTAL,
		variable=replace, command=replace_changed, length=100*pixel_scale(),
		tooltip="Drag slider to adjust amount existing sound is affected")
	replace_scale.grid(row=0, column=4, columnspan=2, padx=pad_x, pady=pad_y, sticky="w")
	replace_label = replace_frame.add_label(anchor="e", width=6, style='Value.TLabel')
	replace_label.grid(row=1, column=5, padx=pad_x, pady=0, sticky="e")
	replace_label['text'] = " %.0f%%" % (replace.get() * 100)
	
	# Level slider	
	level_frame = frame.add_frame()
	level_frame.add_separator(orient=VERTICAL).grid(row=0, rowspan=3, column=3, sticky="ns", padx=pad_x)	
	label = level_frame.add_label(text="Level", anchor="w")
	label.grid(row=1, column=4, padx=pad_x, pady=0, sticky="w")
	def level_changed(loudness_str):
		level_label['text'] = " %.0f dB" % level.get()
	level_scale = level_frame.add_scale(from_=-20.0, to=20.0, orient=HORIZONTAL,
		variable=level, command=level_changed, length=100*pixel_scale(),
		tooltip="Drag slider to adjust sound level")
	level_scale.grid(row=0, column=4, columnspan=2, padx=pad_x, pady=pad_y, sticky="w")
	level_label = level_frame.add_label(anchor="e", width=6, style='Value.TLabel')
	level_label.grid(row=1, column=5, padx=pad_x, pady=0, sticky="e")
	level_label['text'] = " %.0f dB" % level.get()
	
	# Selection tools
	selection_frame = frame.add_frame()
	clipboard_ripcut: Rip = None
	def create_selection_clipboard():
		nonlocal clipboard_ripcut
		if note_exists(edit_note) and selection_slice_range() is not None:		
			# Delete existing clipboard ripcut if exists
			if clipboard_ripcut is not None and clipboard_ripcut: clipboard_ripcut.delete()		
			# Create new clipboard ripcut
			clipboard_name = "[Harmonic Editor Clipboard]"
			clipboard_ripcut = edit_rip.new_ripcut(name=clipboard_name)		
			# Copy selection note to it
			selection_note(clipboard_ripcut)
	def window_cut_pressed(event: Event):
		if note_exists(edit_note) and selection_slice_1 != 0:
			selected_slice_range = selection_slice_range()
			if selected_slice_range is not None:
				create_selection_clipboard()
				# Silence region
				selected_slice_range.volume.amplitude = 0.0
				show_note(edit_note, None)
				update_selection_level()
		return "break"
	def window_copy_pressed(event: Event):
		if note_exists(edit_note) and selection_slice_1 != 0:
			selected_slice_range = selection_slice_range()
			if selected_slice_range is not None:
				create_selection_clipboard()
				update_selection_level()
		return "break"		
	def window_paste_pressed(event: Event):
		# Does clipboard ripcut exist?
		if note_exists(edit_note) and clipboard_ripcut is not None and clipboard_ripcut:
			# Use first note
			for note in clipboard_ripcut.notes:		
				selected_slice_range = selection_slice_range()
				if selected_slice_range is not None:
					# Copy over selection in current note
					# Currently use frequency in mix too - ensures sounds the same
					selected_slice_range.mix_in(slice_range=note.slices)#, mix=TIMBRE|VOLUME|PANNING)
					show_note(edit_note, None)
				break
		return "break"
	cut_button = selection_frame.add_button(image=[cut_image, 'disabled', cut_disabled_image], style='Toolbar.TButton',
		tooltip="Cut selection to clipboard")
	cut_button.grid(row=0, rowspan=2, column=0, padx=0, pady=0, sticky="w")
	cut_button.bind("<Button-1>", window_cut_pressed)
	copy_button = selection_frame.add_button(image=[copy_image, 'disabled', copy_disabled_image], style='Toolbar.TButton',
		tooltip="Copy selection to clipboard")
	copy_button.grid(row=0, rowspan=2, column=1, padx=0, pady=0, sticky="w")
	copy_button.bind("<Button-1>", window_copy_pressed)
	paste_button = selection_frame.add_button(image=[paste_image, 'disabled', paste_disabled_image], style='Toolbar.TButton',
		tooltip="Paste selection from clipboard")
	paste_button.grid(row=0, rowspan=2, column=2, padx=0, pady=0, sticky="w")
	paste_button.bind("<Button-1>", window_paste_pressed)
	def update_selection_level():
		if note_exists(edit_note):
			# Get level for current selection and set to slider
			selected_slice_range = selection_slice_range()
			if selected_slice_range is not None and selection_slice_1 != 0: 
				level = selected_slice_range.volume.db
				sellevel.set(max(-90, min(0, level)))
				sellevel_changed("")
				sellevel_scale.config(state='')
				sellevel_label.config(state='')
				sellevel_static_label.config(state='')
				cut_button.config(state='')
				copy_button.config(state='')
			else:
				sellevel_scale.config(state='disabled')
				sellevel_label.config(state='disabled')
				sellevel_static_label.config(state='disabled')
				cut_button.config(state='disabled')
				copy_button.config(state='disabled')
			if selected_slice_range is not None and clipboard_ripcut is not None and clipboard_ripcut:
				paste_button.config(state='')
			else:
				paste_button.config(state='disabled')
		else:
			sellevel_scale.config(state='disabled')
			sellevel_label.config(state='disabled')
			sellevel_static_label.config(state='disabled')
			cut_button.config(state='disabled')
			copy_button.config(state='disabled')
			paste_button.config(state='disabled')
	selection_frame.add_separator(orient=VERTICAL).grid(row=0, rowspan=2, column=3, sticky="ns", padx=pad_x)	
	sellevel_static_label = selection_frame.add_label(text="Level", anchor="w")
	sellevel_static_label.grid(row=1, column=4, padx=pad_x, pady=0, sticky="w")
	def sellevel_changed(loudness_str):
		sellevel_label['text'] = " %.0f dB" % sellevel.get()
		if note_exists(edit_note):
			selected_slice_range = selection_slice_range()
			if selected_slice_range:
				# Set new level
				selected_slice_range.volume.db = sellevel.get()
				show_note(edit_note, None)
				#play_selection()
	sellevel_scale = selection_frame.add_scale(from_=-50.0, to=20.0, orient=HORIZONTAL,
		variable=sellevel, command=sellevel_changed, length=100*pixel_scale(),
		tooltip="Drag slider to adjust selection sound level")
	def sellevel_scale_click(event: Event):
		# Pause undo storage whilst dragging level
		if note_exists(edit_note): edit_note.edits_start()
	def sellevel_scale_release(event: Event):
		# Resume undo storage after dragging level
		if note_exists(edit_note):
			edit_note.edits_end()
			play_selection()
	sellevel_scale.bind("<Button-1>", sellevel_scale_click)
	sellevel_scale.bind("<ButtonRelease-1>", sellevel_scale_release)
	sellevel_scale.grid(row=0, column=4, columnspan=2, padx=pad_x, pady=pad_y, sticky="w")
	sellevel_label = selection_frame.add_label(anchor="e", width=6, style='Value.TLabel')
	sellevel_label.grid(row=1, column=5, padx=pad_x, pady=0, sticky="e")
	sellevel_label['text'] = " %.0f dB" % sellevel.get()

	# Harmonics combo
	harmonics_frame = frame.add_frame()
	harmonics_frame.add_separator(orient=VERTICAL).grid(row=0, rowspan=2, column=7, sticky="ns", padx=pad_x)
	label = harmonics_frame.add_label(text="Harmonics")
	label.grid(row=1, column=8, padx=pad_x, sticky="w")
	harmonics_combo = harmonics_frame.add_combo_box(values=["All", "Odd", "Even", "3rds", "5ths", "7ths"],
		width = 7, state="readonly", textvariable=harmonics_setting,
		tooltip="Select which harmonics to include")
	harmonics_combo.grid(row=0, column=8, padx=pad_x, pady=0, sticky="w")
	def harmonic_selected(event: Event):
		nonlocal harmonics
		harmonics_combo.selection_clear() # To prevent selected text that shouldn't apply to read-only combo
		if harmonics_setting.get() == "All":
			harmonics = list(range(1, MAX_HARMONIC_MULTIPLE + 1))
		elif harmonics_setting.get() == "Odd":
			harmonics = list(range(1, MAX_HARMONIC_MULTIPLE + 1, 2))
		elif harmonics_setting.get() == "Even":
			harmonics = list(range(2, MAX_HARMONIC_MULTIPLE + 1, 2))
		elif harmonics_setting.get() == "3rds":
			harmonics = list(range(3, MAX_HARMONIC_MULTIPLE + 1, 3))
		elif harmonics_setting.get() == "5ths":
			harmonics = list(range(5, MAX_HARMONIC_MULTIPLE + 1, 5))
		elif harmonics_setting.get() == "7ths":
			harmonics = list(range(7, MAX_HARMONIC_MULTIPLE + 1, 7))
	harmonics_combo.bind("<<ComboboxSelected>>", harmonic_selected)
	harmonic_selected(None)

	# Remove to Another Note option
	transfer_separator = frame.add_separator(orient=VERTICAL)
	transfer_separator.grid(row=0, rowspan=2, column=9, sticky="ns", padx=pad_x)
	transfer_button = frame.add_check_button(text=" Remove To New Layer", variable=remove_to_other,
		tooltip="Removed sound is stored in a new layer")
	transfer_button.grid(row=0, rowspan=2, column=10, padx=pad_x, pady=0, sticky="we")
	def transfer_possible():
		mode = current_editmode()
		return mode == erase_mode or mode == adjust_level_mode or mode == remove_harmonics_mode or mode == remove_spikes_mode or mode == reduce_to_slice_mode or \
			mode == subtract_slice_mode or mode == remove_timbre_mode or mode == keep_timbre_mode
	def update_transfer_button():
		# Disable transfer button if not a transfer mode
		mode = current_editmode()
		if transfer_possible():
			to_state = 'readonly'
		else:
			to_state = 'disabled'
		transfer_button.config(state=to_state)
		if to_state == 'disabled':
			transfer_separator.grid_remove()
			transfer_button.grid_remove()
		else:
			transfer_separator.grid(row=0, rowspan=2, column=9, sticky="ns", padx=pad_x)
			transfer_button.grid(row=0, rowspan=2, column=10, padx=pad_x, pady=0, sticky="we")
	update_transfer_button()
	
	## Instructions
	instructions_frame = window.add_frame()
	instructions_frame.grid(row=1, column=0, columnspan=2, padx=pad_x, pady=2 * pixel_scale(), sticky="we")
	instructions_frame.add_label(image=info_image).grid(row=0, column=0, rowspan=2, padx=0, pady=pad_y, sticky="wen")
	if platform.system() == "Darwin": # Mac OS X
		instructions = harmonic_editor_tools_tips[current_editmode()].replace("Ctrl+", "\u2318-")
		instructions = harmonic_editor_tools_tips[current_editmode()].replace("Alt", "\u2325")
	else:
		instructions = harmonic_editor_tools_tips[current_editmode()]
	mode_instructions = instructions_frame.add_label(text=instructions, foreground='#a0a0a0')
	mode_instructions.grid(row=0, column=1, columnspan=2, padx=pad_x, pady=pad_y, sticky="we")
	#window.add_separator(orient=HORIZONTAL).grid(row=5, column=0, columnspan=2, pady=0, sticky="we")

	## Canvas
	canvas_frame = window.add_frame()
	canvas_frame.grid(row=7, column=0, columnspan=2, padx=2*pixel_scale(), pady=0, sticky=(S,N,W,E))
	canvas_hscoll_max = canvas_width.get()
	canvas_hscale_region = canvas_frame.add_canvas(width=canvas_width.get(), height=16*pixel_scale(), highlightthickness=0, scrollregion=(0,0,canvas_hscoll_max,16*pixel_scale()),
								  background='#000000')
	canvas_hscale_region.grid(row=0, column=0, sticky="nwe")
	canvas = canvas_frame.add_canvas(width=canvas_width.get(), height=canvas_height.get(), highlightthickness=0, scrollregion=(0,0,canvas_hscoll_max,288))
	canvas_hscroll = canvas_frame.add_scrollbar(orient=HORIZONTAL)
	canvas_hscroll.grid(row=2, column=0, sticky="we")
	lasthscroll = -1
	lastheight = -1
	lastwidth = -1
	def canvas_hscrolled(*args):
		nonlocal canvas_after_id, lasthscroll, lastwidth,lastheight
		# Add timer to redraw completely after a bit so looks correctly scaled with lines between harmonics
		#if canvas_after_id: canvas.after_cancel(canvas_after_id)
		#canvas_after_id = canvas.after(50, canvas_redraw)
		canvas_hscroll.set(*args)
		# Since we come in here for resizing too, we only do if not resized so
		# don't redraw twice
		if canvas_hscroll.get()[0] != lasthscroll and \
			canvas.winfo_reqwidth() == lastwidth and canvas.winfo_reqheight() == lastheight:
			lasthscroll = canvas_hscroll.get()[0]
			canvas_redraw()
		lastheight = canvas.winfo_reqheight()
		lastwidth = canvas.winfo_reqwidth()

	def canvas_xviews(*args):
		canvas.xview(*args)
		canvas_hscale_region.xview(*args)
	canvas_hscroll.config(command=canvas_xviews)
	canvas.config(xscrollcommand=canvas_hscrolled)
	canvas.grid(row=1, column=0, sticky="nswe")
	#canvas_hscroll.grid_remove()
	canvas_after_id = 0
	def canvas_redraw():
		nonlocal note_image
		note_image = None
		show_note(edit_note, None)
	def canvas_resize(event: Event):
		# determine the ratio of old width/height to new width/height
		nonlocal harmonic_height, slice_width
		nonlocal canvas_after_id
		if not note_exists(edit_note):
			event.width = max(event.width, 48)
		else:
			event.width = max(event.width, edit_note.number_of_slices)
		event.height = max(event.height, MAX_HARMONIC_MULTIPLE)
		wscale = 1#float(event.width)/canvas_width.get()
		hscale = float(event.height)/canvas_height.get()
		canvas_width.set(event.width)
		canvas_height.set(event.height)
		
		# Hack to fix issue on Mac where dragging the top of the window doesn't move it and resizes the bottom only
		if platform.system() == "Darwin": # Mac OS X
			# Check if we're dragging the top, bottom, left, or right of the window
			# Note that since HM 5, the window passed is actually a frame from a window as custom title bars implemented
			toplevel_window = window.winfo_toplevel()
			mouse_x, mouse_y = [int(c) for c in toplevel_window.winfo_pointerxy()]
			geometry_list = toplevel_window.geometry().split('+')
			top = int(geometry_list[2])
			left = int(geometry_list[1])
			window_size = geometry_list[0].split('x')			
			bottom = int(window_size[1]) + top
			right = int(window_size[0]) + left
			distance_top = abs(top - mouse_y)
			distance_bottom = abs(bottom - mouse_y)
			distance_left = abs(left - mouse_x)
			distance_right = abs(right - mouse_x)
			if distance_top < distance_bottom:
				height_diff = int(canvas.config()['height'][4]) - event.height
				geometry_height = int(geometry_list[2]) + height_diff
				geometry_list[2] = str(geometry_height)
			if distance_left < distance_right:
				width_diff = int(canvas.config()['width'][4]) - event.width
				geometry_width = int(geometry_list[1]) + width_diff
				geometry_list[1] = str(geometry_width)
			if distance_top < distance_bottom or distance_left < distance_right:
				# Adjust window position to account for canvas resize
				window_geometry = '+'.join(geometry_list)
				toplevel_window.geometry(window_geometry)
				
		# resize the canvas 
		canvas.config(width=canvas_width.get(), height=canvas_height.get())
		canvas_hscale_region.config(width=canvas_width.get())
		if note_exists(edit_note):
			# Size of each editable item
			harmonic_height = canvas.winfo_reqheight() / MAX_HARMONIC_MULTIPLE
			# Add timer to redraw completely after a bit so looks correctly scaled with lines between harmonics
			#if canvas_after_id: canvas.after_cancel(canvas_after_id)
			#canvas_after_id = canvas.after(50, canvas_redraw)
		else:
			canvas_hscoll_max = canvas_width.get()
			canvas.config(scrollregion=(0,0,canvas_hscoll_max,canvas_height.get()))
			canvas_hscale_region.config(scrollregion=(0,0,canvas_hscoll_max,16*pixel_scale()))
		canvas_redraw()
	canvas.bind("<Configure>", canvas_resize)
	
	# Handle click and drag in hscale area
	current_time_scale = time_scale.get()
	def time_scale_changed(time_scale_str, centre_x=-1):
		nonlocal current_time_scale, canvas_hscoll_max
		if not note_exists(edit_note): return
		to_time_scale = time_scale.get()
		to_time_scale = (int)(to_time_scale * 128) / 128
		if to_time_scale == current_time_scale: return
		if centre_x == -1: centre_x = canvas.winfo_reqwidth() / 2
		curr_x = (canvas_hscroll.get()[0] * canvas_hscoll_max + centre_x) / current_time_scale
		canvas_hscoll_max = canvas_hscoll_max * to_time_scale / current_time_scale
		canvas.config(scrollregion=(0,0,canvas_hscoll_max,canvas_height.get()))
		canvas.xview('moveto', max(0.0, min(1.0, ( curr_x * to_time_scale - centre_x) / canvas_hscoll_max )))
		canvas_hscale_region.config(scrollregion=(0,0,canvas_hscoll_max,16*pixel_scale()))
		canvas_hscale_region.xview('moveto', max(0.0, min(1.0, ( curr_x * to_time_scale - centre_x) / canvas_hscoll_max )))
		current_time_scale = to_time_scale
		canvas_redraw()
	hscaling = False
	hscaling_start_x = 0
	hscaling_start_y = 0
	hscaling_start_scale = 0
	min_zoom_x = 1
	max_zoom_x = 4
	def canvas_hscale_mouse_click(event):
		nonlocal hscaling, hscaling_start_x, hscaling_start_scale
		hscaling = True
		hscaling_start_x = event.x
		hscaling_start_y = event.y
		hscaling_start_scale = time_scale.get()
	def canvas_hscale_mouse_release(event):
		nonlocal hscaling
		hscaling = False
	def canvas_hscale_motion(event):
		nonlocal hscaling
		# Only zoom if moved more horizontally than vertically to prevent scale change when user clicks in wrong place when editing quickly
		if abs(event.x - hscaling_start_x) > abs(event.y - hscaling_start_y):
			if hscaling:
				if event.x >= hscaling_start_x:
					time_scale.set(min(max_zoom_x, hscaling_start_scale * (1.0 + 0.1 * (event.x - hscaling_start_x) / pixel_scale())))
				else:
					time_scale.set(max(min_zoom_x, hscaling_start_scale / (1.0 + 0.1 * (hscaling_start_x - event.x)/ pixel_scale())))
				time_scale_changed("scale", hscaling_start_x)
	canvas_hscale_region.bind("<Button-1>", canvas_hscale_mouse_click)
	canvas_hscale_region.bind("<ButtonRelease-1>", canvas_hscale_mouse_release)
	canvas_hscale_region.bind("<Motion>", canvas_hscale_motion)

	# Handle mousewheel
	if platform.system() == "Darwin": # Mac OS X
		unit_divider = 1
	else:
		unit_divider = 120
	def on_mousewheel(event: Event):
		# Otherwise scroll
		canvas.xview_scroll(-int(round(event.delta/unit_divider)), "units")
		canvas_hscale_region.xview_scroll(-int(round(event.delta/unit_divider)), "units")
	canvas.bind("<MouseWheel>", on_mousewheel)
	skipMousewheelZoomUntil = 0
	def on_control_mousewheel(event: Event):
		# Ctrl or Cmd held down - zoom
		# NB: If scroll quickly it seems to not have time to adjust everything before we
		# process again, causing it to jump to the wrong position
		nonlocal skipMousewheelZoomUntil
		if skipMousewheelZoomUntil != 0 and event.time < skipMousewheelZoomUntil: return
		this_time_scale = time_scale.get()
		if (int(round(event.delta/unit_divider)) >= 1):
			time_scale.set(min(max_zoom_x, this_time_scale * 1.3))
		else:
			time_scale.set(max(min_zoom_x, this_time_scale / 1.3))
		time_scale_changed("scale", event.x)
		skipMousewheelZoomUntil = event.time + 100
	if platform.system() == "Darwin": # Mac OS X
		canvas.bind("<Command-MouseWheel>", on_control_mousewheel)
	else:
		canvas.bind("<Control-MouseWheel>", on_control_mousewheel)
	
	## Information frame
	info_frame = window.add_frame()
	info_frame.grid(row=8, column=0, columnspan=2, padx=pad_x, pady=2*pixel_scale(), sticky="we")
	global frequency_text, frequency_static_text, time_text, time_static_text, db_text
	db_text = info_frame.add_label(text="", width = 7, style='Value.TLabel')
	db_text.grid(row=0, column=2, padx=pad_x)
	frequency_static_text = info_frame.add_label(text="", width = 9)
	frequency_static_text.grid(row=0, column=3, padx=0)
	frequency_text = info_frame.add_label(text="", width = 14, style='Value.TLabel')
	frequency_text.grid(row=0, column=4, padx=0)
	time_static_text = info_frame.add_label(text="", width = 9)
	time_static_text.grid(row=0, column=5, padx=0)
	time_text = info_frame.add_label(text="", style='Value.TLabel')
	time_text.grid(row=0, column=6, padx=0)
	# For showing instructions when hovering menu items (in place of above)
	#mode_temp_instructions = window.add_label(text="", foreground='#a0a0a0')
	#mode_temp_instructions.grid(row=8, column=0, columnspan=2, padx=pad_x, pady=pad_y, sticky="we")
	
	edit_note: Note = None
	edit_rip: Rip = None
	def update_layers():
		if not show_layers: return
		nonlocal layers
		layers = [ "All" ]
		if layer_combo is not None:
			new_layer = max(0, layer_combo.current())
		else:
			new_layer = 0
		max_layers = 0
		if note_exists(edit_note):
			# Find max layers used
			for harmonic in edit_note.slices.harmonics:
				max_layers = max(max_layers, harmonic.number_of_layers)
			for layer in range(1, max_layers + 1):
				layers.append(str(layer))
		layer_combo['values'] = layers
		if new_layer > max_layers: new_layer = max_layers
		layer_combo.current(new_layer)
	def set_layer(event: Event):
		layer_combo.selection_clear() # To prevent selected text that shouldn't apply to read-only combo
		show_note(edit_note, None)
		play()
	if show_layers:
		layers = [ "All" ]
		layer_combo = info_frame.add_combo_box(values=layers, state="readonly", width=5)
		layer_combo.grid(row=0, column=3, sticky="w")
		label = info_frame.add_label(text="Visible Layer")
		label.grid(row=0, column=2, sticky="e")
		layer_combo.bind("<<ComboboxSelected>>", set_layer)
		update_layers()

	# Specify what is resizable (row 1, column 0)
	window.rowconfigure(7, weight=1)
	window.columnconfigure(0, weight=1)
	canvas_frame.rowconfigure(1, weight=1)
	canvas_frame.columnconfigure(0, weight=1)
	
	# Stop RipScript if window closed
	def window_closed(event):
		if event.widget == window: # Otherwise occurs for every widget in window
			if clipboard_ripcut and clipboard_ripcut is not None: clipboard_ripcut.delete()
			clear_reset_note()
			settings.save()
			view.unbind("<All>")
	window.winfo_toplevel().bind("<Destroy>", window_closed)

	harmonic_height = 0
	slice_width = 0
	edit_note_volume = DB_SILENT
	source_note: Note = None
	last_edit_time = None
	last_edit_harmonic = None
	editing_note = False
	mix = TIMBRE | VOLUME
	effect_function = None
	canvas_spotlight = None
	canvas_spotlight_fade_in = None
	canvas_spotlight_fade_out = None
	selecting_region = False
	region_selected = False
	selection_harmonic_0 = selection_harmonic_1 = 0
	selection_slice_0 = selection_slice_1 = 0
	
	# Default font family
	font_family = TkFont.nametofont("TkDefaultFont").cget("family")

	def visible_layer():
		if show_layers:
			return layer_combo.current()
		else:
			return 0 # All
			
	note_image_x = 0
	note_image_from_slice =0
	note_image_num_slices = 0
	
	# Return colour for loudness
	def loudness_colour(loudness, boost=4):
		# Darkness of rectangle
		darkness = int(round(min(511, 511 * loudness * boost)))
		if darkness <= 255:
			r = (int)(0x8a * darkness / 256)
			g = (int)(0xc2 * darkness / 256)
			b = (int)(0xf2 * darkness / 256)
		else:
			r = (int)(0x8a + 0x75 * (darkness - 256) / 256)
			g = (int)(0xc2 - 0xc2 * (darkness - 256) / 256)
			b = (int)(0xf2 - 0xf2 * (darkness - 256) / 256)
		return "#%02x%02x%02x" % (r, g, b)
			
	# Function to add note details to canvas
	def show_note(note: Note, update_region):
		nonlocal canvas, edit_note, edit_rip
		nonlocal harmonic_height
		nonlocal slice_width
		nonlocal canvas_hscoll_max
		nonlocal note_image, canvas_image, font_family
		nonlocal note_image_x, note_image_from_slice, note_image_num_slices
		
		# Check rip exists
		rip = edit_rip
		if rip is None or not rip:
			note = edit_note = None
			edit_rip = None
		
		force_black_blocks = update_region is not None
		update_beat_markers = False
		if update_region is None or not note_exists(note):
			# Clear all objects
			canvas.delete("all")
			update_beat_markers = True
			if note_image is not None:
				draw = ImageDraw.Draw(note_image)
				draw.rectangle((0, 0) + note_image.size, fill=(0, 0, 0, 0))
			if note is None or not note:
				canvas.create_rectangle(0, 0, canvas.winfo_reqwidth(), canvas.winfo_reqheight(), fill="#000000")
				tk_rgb = "#%02x%02x%02x" % (2 * 0x45, 2 * 0x61, 2 * 0x79)
				canvas.create_text(canvas.winfo_reqwidth() / 2 + canvas_hscroll.get()[0] * canvas_hscoll_max, canvas.winfo_reqheight() / 2,
					text="Click a Note\n\n(Select main Move/Resize tool first if necessary)", fill=tk_rgb,justify='center')
				canvas_hscale_region.delete("all")
				canvas_hscale_region.create_rectangle(0, 0, canvas_hscoll_max, canvas_hscale_region.winfo_reqheight(), fill="#000000")
				return
			# Create huge black background so don't see it when scrolling
			slice_width = max(min_slice_width, canvas.winfo_reqwidth() / note.number_of_slices) * time_scale.get()
			canvas_hscoll_max = slice_width*note.number_of_slices
			canvas.create_rectangle(0, 0, canvas_hscoll_max, canvas.winfo_reqheight(), fill="#000000")
			note_image = None

		if note_image is None:
			# Slice width etc
			slice_width = max(min_slice_width, canvas.winfo_reqwidth() / note.number_of_slices) * time_scale.get()
			canvas_hscoll_max = slice_width*note.number_of_slices
			canvas.config(scrollregion=(0,0,canvas_hscoll_max,canvas_height.get()))
			canvas_hscale_region.config(scrollregion=(0,0,canvas_hscoll_max,16*pixel_scale()))
			# Create PIL image
			note_image_from_slice = int(canvas_hscroll.get()[0] * canvas_hscoll_max / slice_width)
			note_image_x = note_image_from_slice * slice_width
			note_image_num_slices = int(canvas.winfo_reqwidth() / slice_width + 3)
			note_image_width = int(note_image_num_slices * slice_width)
			note_image = Image.new(mode='RGB', color='black', size=(note_image_width,int(canvas_height.get()*pixel_scale())))

		# Size of each editable item
		harmonic_height = canvas.winfo_reqheight() / MAX_HARMONIC_MULTIPLE
	
		if update_region is None:
			if show_adjusted.get():
				number_of_harmonics = MAX_HARMONIC_MULTIPLE # Since formants etc can occupy new higher harmonics
			else:
				number_of_harmonics = note.number_of_harmonics
			update_region = [ 1, note.number_of_slices + 1, range(1, number_of_harmonics + 1) ]
		else:
			# Clear objects in region
			for slice_position in range(update_region[0], update_region[1]):
				for harmonic_multiple in update_region[2]:
					tag = str(slice_position) + "_" + str(harmonic_multiple)
					canvas.delete(tag)
					
		# Restrict to visible region
		update_region[0] = max(update_region[0], note_image_from_slice)
		update_region[1] = min(update_region[1], note_image_from_slice + note_image_num_slices)

		# Layer
		show_layer = visible_layer()
		
		# If in note edit drag, pause so volume returns current loudness as opposed to pre-edit value
		if editing_note: note.edits_pause()
		
		# Add a rectangle for each
		x = (update_region[0] - 1 - note_image_from_slice) * slice_width
		draw = ImageDraw.Draw(note_image)
		# Create table of loudness values for all layers for slice range
		format = LOUDNESS
		if show_adjusted.get(): format += ADJUSTED
		loudness_table = note.slice_range(start=note.time_at(position=update_region[0]),
			end=note.time_at(position=update_region[1])).volume_table(format=format)
		for slice_position in range(update_region[0], update_region[1]):
			for harmonic_multiple in update_region[2]:		
				total_loudness = loudness_table[harmonic_multiple-1][slice_position-update_region[0]]		
				if force_black_blocks or total_loudness > 0.003: # Faster with less rectangles especially on macOS
					tk_rgb = loudness_colour(total_loudness, current_contrast)
					y = canvas.winfo_reqheight() - harmonic_height * harmonic_multiple
					draw.rectangle([(x, y), (x + slice_width, y + harmonic_height - 2)], fill=tk_rgb)
				
			x += slice_width
		
		# Add image
		canvas_image = ImageTk.PhotoImage(note_image)
		canvas.create_image(note_image_x, 0, image=canvas_image, anchor='nw')

		# Update beat markers
		canvas.delete("beat_marker")
		canvas_hscale_region.delete("all")
		canvas_hscale_region.create_rectangle(0, 0, canvas_hscoll_max, canvas_hscale_region.winfo_reqheight(), fill="#000000")
		# Note that if a note starts/ends before the first bar, a None will be returned, so we handle this here
		start_bar_index = 1
		start_bar = rip.bar_at(time=note.start)
		if start_bar is not None: start_bar_index = start_bar.number
		end_bar_index = 1
		end_bar = rip.bar_at(time=note.end)
		if end_bar is not None: end_bar_index = end_bar.number
		y1 = canvas.winfo_reqheight()
		for bar_number in range(start_bar_index, end_bar_index + 1):
			bar = rip.bar(number=bar_number)
			bar_start = bar.start
			bar_duration = bar.duration
			# Draw visible bar markings
			beat_markers = bar.beat_markers(at_zoom=slice_width/4)
			for beat in beat_markers:
				if beat[1] == 0:
					tk_rgb_hl = "#%02x%02x%02x" % (0xa0, 0xa0, 0xa0)	# Level 0 - bar level
				elif beat[1] == 1:
					tk_rgb_hl = "#%02x%02x%02x" % (0x60, 0x60, 0x60)	# Level 1 - top beat level
				else:
					tk_rgb_hl = "#%02x%02x%02x" % (0x30, 0x30, 0x30)	# Level 2 - subdivisions
				time = bar_start + beat[0] * bar_duration
				x = int((time - note.start) / note.slice_duration + 0.5) * slice_width
				if x >= 0 and x < canvas.winfo_reqwidth() + canvas_hscoll_max:
					canvas.create_line(x, 0, x, y1, fill=tk_rgb_hl, tags="beat_marker")
					canvas_hscale_region.create_text(x, 11, text=time_string(time), font=(font_family, 10), fill="#%02x%02x%02x" % (0xa0, 0xa0, 0xa0))
			# Ensure we don't forget the first bar's start line if necessary
			if bar_number == 1:
				tk_rgb_hl = "#%02x%02x%02x" % (0xa0, 0xa0, 0xa0)	# Level 0 - bar level
				time = bar.start
				x = int((time - note.start) / note.slice_duration + 0.5) * slice_width
				if x >= 0 and x < canvas.winfo_reqwidth() + canvas_hscoll_max:
					canvas.create_line(x, 0, x, y1, fill=tk_rgb_hl, tags="beat_marker")
					canvas_hscale_region.create_text(x, 11, text=time_string(time), font=(font_family, 10), fill="#%02x%02x%02x" % (0xa0, 0xa0, 0xa0))
				
		# Resume edits if paused
		if editing_note: note.edits_start()
		
		# Re-add other graphics components
		update_slice_anchor()
		update_selection_marker()
		update_timbre_text()
		
		# Set cursor
		set_cursor()
		
	working_ripcut: Rip = None
	reset_note: Note = None
	def create_reset_note(note: Note):
		nonlocal working_ripcut, reset_note
		if edit_rip is None: return
		if not note_exists(note): return

		# Check whether note is different from current one being edited
		if note_exists(edit_note) and note == edit_note: return

		# Check whether a Note Editor working RipCut is present
		if not working_ripcut or working_ripcut is None:
			# Create working RipCut
			working_ripcut = edit_rip.new_ripcut(name="[Harmonic Editor Workspace]")

		# Delete existing reset note
		if reset_note is not None and reset_note:
			reset_note.delete()
			
		# Create reset note
		if not working_ripcut or working_ripcut is None: return
		reset_note = note.copy_to(time=0.0, rip=working_ripcut)

	def clear_reset_note():
		nonlocal working_ripcut, reset_note
		# Delete note
		if reset_note is not None and reset_note:
			reset_note.delete()
		# Delete ripcut
		if working_ripcut is not None and working_ripcut:
			working_ripcut.delete()
	
	def view_mouse_click(event: ViewEvent):
		nonlocal edit_note, edit_rip, region_selected, anchor_slice, playback_rip
		if event.note and event.note is not None and (not edit_note or event.note != edit_note):
			anchor_slice = 0
			clear_selection()
			edit_rip = ripx.current_view.rip
			create_reset_note(event.note)
			edit_note = event.note
			#if edit_note.grouped_notes is not None:
			#	ripx.pop_up(message="This is a group of notes - only one will be shown", duration=3.5)
			# If already playing set as playback rip
			if edit_rip.playback_time is not None:
				playback_rip = edit_rip
				playback_starttime = playback_rip.playback_time
				play_update()
				window.after(40, play_update)
				play_button.config(image=stop_image)
			canvas.xview('moveto', 0)
			canvas_hscale_region.xview('moveto', 0)
			update_layers()
			show_note(edit_note, None)	
		return "to_ripx"
			
	def view_undo(event: ViewEvent):
		# Undo/redo occurred - redisplay note
		#if view.has_control:
		update_layers()
		show_note(edit_note, None)
			
	# Create callback to show clicked note
	view = ripx.current_view
	view.bind("<Button-1>", view_mouse_click)
	view.bind("<Undo>", view_undo)
	
	def in_slice_mode():
		mode = current_editmode()
		return mode == reduce_to_slice_mode or mode == increase_to_slice_mode or \
			mode == add_slice_mode or mode == subtract_slice_mode or \
			mode == clone_from_slice_mode
	
	def in_timbre_mode():
		mode = current_editmode()
		return mode == remove_timbre_mode or mode == keep_timbre_mode
		
	def adjust_and_transfer(layer_slice, transfer_layer_slice, loudness_adjust):
									
		if transfer_layer_slice is not None:
			# As in note edit drag, pause so volume returns current loudness as opposed to pre-edit value
			edit_note.edits_pause()
			original_amp = layer_slice.volume.amplitude
			edit_note.edits_start()
		
		# Update
		layer_slice.volume.loudness *= loudness_adjust
		
		if transfer_layer_slice is not None:
			# Get new amplitude and transfer difference to other note
			edit_note.edits_pause()
			new_amp = layer_slice.volume.amplitude
			edit_note.edits_start()	
			if transfer_layer_slice.volume.amplitude == 0:
				# Set up frequency and phase from original
				transfer_layer_slice.pitch.frequency = layer_slice.pitch.frequency
				for channel in CHANNELS:
					transfer_layer_slice.phase[channel] = layer_slice.phase[channel]
			transfer_layer_slice.volume.amplitude += original_amp - new_amp
			
	def level_for_mode():
		return float(level.get())
			
	def get_brush_duration_and_fade():
		edit_note_slice_duration = edit_note.slice_duration
		this_duration = edit_note_slice_duration * max(1, round(float(brush_duration.get()) / edit_note_slice_duration))
		fade_in = fade_out = edit_note_slice_duration * min(1, round(float(brush_duration.get()) / 8 / edit_note_slice_duration))
		return this_duration, fade_in, fade_out

	def apply_edit(edit_time, edit_harmonic):

		# Mix audio from source_note (or nothing) to edit_note centred at time
						
		# Make local copies of fade so can adjust in case need to clip edit region to note
		this_duration, this_fade_in, this_fade_out = get_brush_duration_and_fade()
		volume = level_for_mode()
		
		# How much to expand time and harmonics to cover any lag from last edit
		start_lag_time = 0
		end_lag_time = 0
		nonlocal last_edit_time
		if last_edit_time is not None:
			if edit_time > last_edit_time:
				start_lag_time = edit_time - last_edit_time
			else:
				end_lag_time = last_edit_time - edit_time
		last_edit_time = edit_time
		
		# Create list of harmonics to process since last edit
		nonlocal last_edit_harmonic
		harmonic_list = [edit_harmonic]
		min_edit_harmonic = max_edit_harmonic = edit_harmonic
		if last_edit_harmonic is not None:
			if edit_harmonic > last_edit_harmonic:
				for multiple in range(last_edit_harmonic, edit_harmonic):
					harmonic_list.append(multiple)
			else:
				for multiple in range(edit_harmonic + 1, last_edit_harmonic + 1):
					harmonic_list.append(multiple)
			min_edit_harmonic = min(last_edit_harmonic, edit_harmonic)
			max_edit_harmonic = max(last_edit_harmonic, edit_harmonic)
		last_edit_harmonic = edit_harmonic	
		# Remove any harmonics from list that are not valid multiples or one of
		# the requested harmonics from the Sound Palette
		harmonic_list = [multiple for multiple in harmonic_list
				if (multiple >= 1 and multiple <= MAX_HARMONIC_MULTIPLE and
					multiple in harmonics)]
		if not harmonic_list:
			return None
		
		edit_time_start = edit_time - start_lag_time - this_duration / 2
		# Clip to start of note/selection and adjust this_fade_in accordingly
		unclipped_edit_time_start = edit_time_start
		clip_time_start = 0
		if region_selected and selection_slice_1 != 0:
			clip_time_start = max(clip_time_start, edit_note.time_at(min(selection_slice_0, selection_slice_1)))
		if edit_time_start < clip_time_start:
			this_fade_in = max(0, this_fade_in - (clip_time_start - edit_time_start))
			edit_time_start = clip_time_start
			
		# Adjust to slice
		edit_time_start = edit_note.time_at(edit_note.slice_at(edit_time_start))
		edit_time_end = edit_time_start + this_duration + min(0, unclipped_edit_time_start + edit_note.slice_duration / 4)
		#edit_time_end = edit_note.time_at(edit_note.slice_at(edit_time_end))
		
		# Clip to end of note/selection and adjust this_fade_out accordingly
		clip_time_end = edit_note.duration
		if region_selected and selection_slice_1 != 0:
			clip_time_end = min(clip_time_end, edit_note.time_at(max(selection_slice_0, selection_slice_1) + 1))
		if edit_time_end > clip_time_end:
			this_fade_out = max(0, this_fade_out - (edit_time_end - clip_time_end))
			edit_time_end = clip_time_end
		if edit_time_end <= edit_time_start:
			return None
		edit_slice_start = edit_note.slice_at(edit_time_start)
		edit_slice_end = edit_note.slice_at(edit_time_end) - 1
		
		# Mask to selection harmonically
		if region_selected and selection_slice_1 != 0:
			harmonic_list = [multiple for multiple in harmonic_list
				if (multiple >= min(selection_harmonic_0, selection_harmonic_1) and
				multiple <= max(selection_harmonic_0, selection_harmonic_1))]
			min_edit_harmonic = max(min_edit_harmonic, min(selection_harmonic_0, selection_harmonic_1))
			max_edit_harmonic = min(max_edit_harmonic, max(selection_harmonic_0, selection_harmonic_1))				
			if not harmonic_list:
				return None

		# NB: Not used for palette_mode or erase_mode
		## TODO: Would need slice_range to support specifying layers
		edit_layer = visible_layer()
		mode = current_editmode()
		
		# Set up transfer_slice to send removed amplitude to
		transfer_slice = None
		if transfer_note and (mode == palette_mode or mode == erase_mode or \
			mode == adjust_level_mode or in_timbre_mode()):
			transfer_slice = transfer_note.slice_range(edit_time_start, min(transfer_note.end, edit_time_end), harmonic_list)

		if mode == palette_mode:
						
			## Paint with Sound Palette Mode
			if source_note is not None:
				# Mix with source note
				source_time_start = edit_time - start_lag_time - this_duration / 2
				unclipped_source_time_start = source_time_start
				source_time_start = source_note.time_at(source_note.slice_at(max(0, source_time_start)))
				source_time_end = source_time_start + this_duration + min(0, unclipped_source_time_start + source_note.slice_duration / 4)
				
				edit_note.slice_range(edit_time_start, edit_time_end, harmonic_list).mix_in(
					source_note.slice_range(source_time_start, source_time_end),
					this_volume=edit_note_volume, volume=volume, fade_in=this_fade_in, fade_out=this_fade_out,
					transpose_by=0, mix=mix, effect=effect_function, remove_to=transfer_slice)
			else:
				# Mix with nothing - ie. lower amplitude or apply pure effect
				edit_note.slice_range(edit_time_start, edit_time_end, harmonic_list).mix_in(
					this_volume=edit_note_volume, fade_in=this_fade_in, fade_out=this_fade_out, remove_to=transfer_slice)
					
		elif mode == erase_mode:
			## Erase Mode
			# Mix with nothing - ie. lower amplitude or apply pure effect
			edit_note.slice_range(edit_time_start, edit_time_end, harmonic_list).mix_in(
				this_volume=edit_note_volume, fade_in=this_fade_in, fade_out=this_fade_out, remove_to=transfer_slice)
					
		elif mode == adjust_level_mode:
			## Adjust Level Mode
			# Mix with nothing - ie. lower/raise amplitude using level (rather than replacement)
			edit_note.slice_range(edit_time_start, edit_time_end, harmonic_list).mix_in(
				this_volume=volume, fade_in=this_fade_in, fade_out=this_fade_out, remove_to=transfer_slice)
				
		elif mode == blend_mode:
			## Blend Mode
			# Set amplitude of each slice to overall amplitude of slices, using Sound Palette Replace value
			this_replace = replace.get()
			max_edit_harmonic = min(max_edit_harmonic, edit_note.number_of_harmonics)
			slice_range = edit_note.slice_range(edit_time_start, edit_time_end)
			for harmonic_multiple in range(min_edit_harmonic, max_edit_harmonic + 1):
				for layer in slice_range.harmonic(harmonic_multiple).layers:
					blended_amplitude = layer.volume.amplitude
					for slice_index in range(edit_slice_start, edit_slice_end + 1):
						original_amp = 0
						if this_replace < 1.0: original_amp = layer.slice(position=slice_index).volume.amplitude
						layer.slice(position=slice_index).volume.amplitude = blended_amplitude * this_replace + original_amp * (1 - this_replace)

		elif in_timbre_mode():
			## Remove/keep timbre from note
			keep_timbre = False
			if mode == keep_timbre_mode: keep_timbre = True
			edit_note.slice_range(edit_time_start, edit_time_end, harmonic_list).remove_timbre(
				timbre_note.slices, volume=volume, fade_in=this_fade_in, fade_out=this_fade_out,
				remove_other=keep_timbre, remove_to=transfer_slice)
					
		elif mode == remove_harmonics_mode:
			## Remove Harmonics Mode
			# For each slice look at harmonics above and below and reduce to the average
			max_edit_harmonic = min(max_edit_harmonic, edit_note.number_of_harmonics)
			transfer_amp = note_exists(transfer_note)
			for harmonic_multiple in range(min_edit_harmonic, max_edit_harmonic + 1):
				slice_range = edit_note.slice_range(edit_time_start, edit_time_end)
				for slice_index in range(edit_slice_start, edit_slice_end + 1):
					loudness_this = loudness_above = loudness_below = 0
					for layer in slice_range.harmonic(harmonic_multiple).layers:
						if edit_layer == 0 or layer.number == edit_layer:
							loudness_this += layer.slice(position=slice_index).volume.loudness
					if loudness_this > 0:
						if harmonic_multiple > 1:
							for layer in slice_range.harmonic(harmonic_multiple - 1).layers:
								if edit_layer == 0 or layer.number == edit_layer:
									loudness_below += layer.slice(position=slice_index).volume.loudness
						if harmonic_multiple < edit_note.number_of_harmonics:
							for layer in slice_range.harmonic(harmonic_multiple + 1).layers:
								if edit_layer == 0 or layer.number == edit_layer:
									loudness_above += layer.slice(position=slice_index).volume.loudness
						if harmonic_multiple == 1:
							loudness_below = loudness_above
						loudness_adjust = (loudness_below + loudness_above) / 2 / loudness_this
						if loudness_adjust < 1.0:
											
							transfer_harmonic = None
							if transfer_amp: transfer_harmonic = transfer_note.slices.harmonic(harmonic_multiple)

							for layer in slice_range.harmonic(harmonic_multiple).layers:
								if edit_layer == 0 or layer.number == edit_layer:
									if transfer_harmonic is None:
										adjust_and_transfer(layer.slice(position=slice_index), None, loudness_adjust)
									else:
										adjust_and_transfer(layer.slice(position=slice_index), transfer_harmonic.layer(layer.number).slice(slice_index), loudness_adjust)
					
		elif mode == remove_spikes_mode:
			## Remove Noise Spikes Mode
			# For each harmonic look at slices before and after and reduce to the average
			# If both sides of spotlight outside, use edges
			if edit_slice_start <= 1 and edit_slice_end > edit_note.number_of_slices - 1:
				edit_slice_start = 2
				edit_slice_end = edit_note.number_of_slices - 1
			slices_to_average = int(max(1, min(3, (edit_slice_end - edit_slice_start) / 3)))
			slice_range = edit_note.slices
			max_edit_harmonic = min(max_edit_harmonic, edit_note.number_of_harmonics)
			transfer_amp = note_exists(transfer_note)
			for harmonic_multiple in range(min_edit_harmonic, max_edit_harmonic + 1):
				loudness_before = loudness_after = 0
				
				if edit_slice_start > 1:
					slice_from = max(1, edit_slice_start - slices_to_average)
					for slice_index in range(slice_from, edit_slice_start):
						for layer in slice_range.harmonic(harmonic_multiple).layers:
							if edit_layer == 0 or layer.number == edit_layer:
								loudness_before += layer.slice(position=slice_index).volume.loudness
					loudness_before /= edit_slice_start - slice_from
					
				if edit_slice_end < edit_note.number_of_slices:
					slice_to = min(edit_note.number_of_slices + 1, edit_slice_end + slices_to_average + 1)
					for slice_index in range(edit_slice_end + 1, slice_to):
						for layer in slice_range.harmonic(harmonic_multiple).layers:
							if edit_layer == 0 or layer.number == edit_layer:
								loudness_after += layer.slice(position=slice_index).volume.loudness
					loudness_after /= slice_to - (edit_slice_end + 1)
					
				# If one side out, use the other
				if edit_slice_start <= 1: loudness_before = loudness_after
				if edit_slice_end >= edit_note.number_of_slices: loudness_after = loudness_before
				
				transfer_harmonic = None
				if transfer_amp: transfer_harmonic = transfer_note.slices.harmonic(harmonic_multiple)
					
				# Go through each slice within brush duration limiting loudness to
				# a gradient value between loudness_before and loudness_after
				weight_divisor = edit_slice_end - edit_slice_start + 2
				for slice_index in range(edit_slice_start, edit_slice_end + 1):
					loudness_this = 0
					for layer in slice_range.harmonic(harmonic_multiple).layers:
						if edit_layer == 0 or layer.number == edit_layer:
							loudness_this += layer.slice(position=slice_index).volume.loudness
					if loudness_this > 0:
						max_loudness = loudness_before * (edit_slice_end + 1 - slice_index) / weight_divisor + \
							loudness_after * (slice_index + 1 - edit_slice_start) / weight_divisor	
						loudness_adjust = max_loudness / loudness_this
						if loudness_adjust < 1.0:
							for layer in slice_range.harmonic(harmonic_multiple).layers:
								if edit_layer == 0 or layer.number == edit_layer:
									if transfer_harmonic is None:
										adjust_and_transfer(layer.slice(position=slice_index), None, loudness_adjust)
									else:
										adjust_and_transfer(layer.slice(position=slice_index), transfer_harmonic.layer(layer.number).slice(slice_index), loudness_adjust)
								
		elif in_slice_mode():
			if anchor_slice >= 1 and anchor_slice <= edit_note.number_of_slices:
				# Limit/Increase loudness of all slices to same harmonic at anchor_slice
				limit_loudness = mode == reduce_to_slice_mode or mode == subtract_slice_mode
				cloning = mode == clone_from_slice_mode
				adding_subtracting = mode == add_slice_mode or \
					mode == subtract_slice_mode or cloning
				slice_range = edit_note.slices
				transfer_amp = limit_loudness and note_exists(transfer_note)
				if cloning:
					nonlocal edit_anchor_slice_start, edit_anchor_slice_end
					edit_anchor_slice_start = anchor_slice + edit_slice_start - edit_anchor_slice
					edit_anchor_slice_end = anchor_slice + edit_slice_end - edit_anchor_slice
				for harmonic_multiple in range(min_edit_harmonic, max_edit_harmonic + 1):
					# Get anchor slice loudness
					if not cloning:
						# Get fixed anchor loudness
						anchor_slice_loudness = 0
						for layer in slice_range.harmonic(harmonic_multiple).layers:
							if edit_layer == 0 or layer.number == edit_layer:
								anchor_slice_loudness += layer.slice(position=anchor_slice).volume.loudness
						anchor_slice_loudness *= db(volume).loudness	
									
					transfer_harmonic = None
					if transfer_amp: transfer_harmonic = transfer_note.slices.harmonic(harmonic_multiple)

					# Go through each slice to be affected by this
					for slice_index in range(edit_slice_start, edit_slice_end + 1):
						if cloning:
							# Get relative anchor loudness
							this_anchor_slice = anchor_slice + slice_index - edit_anchor_slice
							anchor_slice_loudness = 0
							if this_anchor_slice >= 1 and this_anchor_slice <= edit_note.number_of_slices:			
								for layer in slice_range.harmonic(harmonic_multiple).layers:
									if edit_layer == 0 or layer.number == edit_layer:
										anchor_slice_loudness += layer.slice(position=this_anchor_slice).volume.loudness
								anchor_slice_loudness *= db(volume).loudness
						loudness_this = 0
						for layer in slice_range.harmonic(harmonic_multiple).layers:
							if edit_layer == 0 or layer.number == edit_layer:
								loudness_this += layer.slice(position=slice_index).volume.loudness
						if loudness_this > 0:
							if adding_subtracting:
								if limit_loudness:
									loudness_adjust = max(0, loudness_this - anchor_slice_loudness) / loudness_this
								else:
									loudness_adjust = (loudness_this + anchor_slice_loudness) / loudness_this
							else:
								loudness_adjust = anchor_slice_loudness / loudness_this
							if (limit_loudness and loudness_adjust < 1.0) or (not limit_loudness and loudness_adjust > 1.0):
								for layer in slice_range.harmonic(harmonic_multiple).layers:
									if edit_layer == 0 or layer.number == edit_layer:
										if transfer_harmonic is None:
											adjust_and_transfer(layer.slice(position=slice_index), None, loudness_adjust)
										else:
											adjust_and_transfer(layer.slice(position=slice_index), transfer_harmonic.layer(layer.number).slice(slice_index), loudness_adjust)
											
						elif not limit_loudness:
							# If no amplitude exists, need to set all to first/visible layer
							layer = slice_range.harmonic(harmonic_multiple).layer(max(1, edit_layer))
							layer.slice(position=slice_index).volume.loudness = anchor_slice_loudness
							
		# Return the region updated so can update note display
		return [ edit_slice_start, edit_slice_end + 1, harmonic_list ]
		
	def harmonic_and_slice_for_event(event: Event):
		nonlocal slice_width
		if not note_exists(edit_note) or slice_width == 0: return 0,0
		nonlocal harmonic_height
		this_slice = 1 + int(round((event.x + canvas_hscroll.get()[0] * canvas_hscoll_max) / slice_width - 0.5))
		this_harmonic = 1 + int((canvas.winfo_reqheight() - event.y) / harmonic_height)
		this_slice = max(1, min(edit_note.number_of_slices, this_slice))
		this_harmonic = max(1, min(MAX_HARMONIC_MULTIPLE, this_harmonic))
		return this_harmonic, this_slice
		
	def selection_slice_range():
		# Return slice_range for selection
		if not note_exists(edit_note) or not region_selected: return None
		
		min_harmonic = max(1, min(selection_harmonic_0, selection_harmonic_1))
		max_harmonic = min(max(selection_harmonic_0, selection_harmonic_1), edit_note.number_of_harmonics) # Ensure we don't add new harmonics to edit_note
		if max_harmonic < min_harmonic: return None
		if selection_slice_1 == 0 and selection_slice_0 >= 1:
			start_slice = selection_slice_0
			end_slice = len(edit_note.slices)	# For when have selection line rather than rectangle
		else:
			start_slice = min(selection_slice_0, selection_slice_1)
			end_slice = max(selection_slice_0, selection_slice_1)
		return edit_note.slice_range(
			start=edit_note.time_at(start_slice),
			end=edit_note.time_at(end_slice + 1),
			harmonics=range(min_harmonic, max_harmonic + 1))
			
	def update_slice_anchor():
		nonlocal anchor_slice
		canvas.delete("slice_anchor")
		if note_exists(edit_note) and in_slice_mode():
			if anchor_slice:
				anchor_slice_start = anchor_slice_end = anchor_slice
				if current_editmode() == clone_from_slice_mode:
					if editing_note:
						anchor_slice_start = edit_anchor_slice_start
						anchor_slice_end = edit_anchor_slice_end
				canvas.create_rectangle(
					(anchor_slice_start - 1) * slice_width,
					1,
					anchor_slice_end * slice_width - 1,
					canvas.winfo_reqheight() - 2, width=2,
					outline="#8ac2f2", tags="slice_anchor")
				canvas.config(cursor="arrow") # Was "none" - but confusing to tell where to click
			else:
				canvas.create_rectangle(canvas_hscroll.get()[0] * canvas_hscoll_max, canvas.winfo_reqheight() / 2 - 16,
					canvas_hscroll.get()[0] * canvas_hscoll_max + canvas.winfo_reqwidth(), canvas.winfo_reqheight() / 2 + 16,
					fill="#000000", tags="slice_anchor")
				tk_rgb = "#ffffff"
				if platform.system() == "Darwin": # Mac OS X
					canvas.create_text(canvas.winfo_reqwidth() / 2 + canvas_hscroll.get()[0] * canvas_hscoll_max, canvas.winfo_reqheight() / 2,
						text="\u2318-Click to select a Time Slice", fill=tk_rgb, tags="slice_anchor")
				else:
					canvas.create_text(canvas.winfo_reqwidth() / 2 + canvas_hscroll.get()[0] * canvas_hscoll_max, canvas.winfo_reqheight() / 2,
						text="Ctrl+Click to select a Time Slice", fill=tk_rgb, tags="slice_anchor")
				canvas.config(cursor="arrow")

	def update_timbre_text():
		canvas.delete("timbre_text")
		if note_exists(edit_note) and in_timbre_mode():
			if not note_exists(timbre_note):
				canvas.create_rectangle(canvas_hscroll.get()[0] * canvas_hscoll_max, canvas.winfo_reqheight() / 2 - 16,
					canvas_hscroll.get()[0] * canvas_hscoll_max + canvas.winfo_reqwidth(), canvas.winfo_reqheight() / 2 + 16,
					fill="#000000", tags="timbre_text")
				tk_rgb = "#ffffff"
				if platform.system() == "Darwin": # Mac OS X
					canvas.create_text(canvas.winfo_reqwidth() / 2 + canvas_hscroll.get()[0] * canvas_hscoll_max, canvas.winfo_reqheight() / 2,
						text="\u2318-Click a Note in Rip", fill=tk_rgb, tags="timbre_text")
				else:
					canvas.create_text(canvas.winfo_reqwidth() / 2 + canvas_hscroll.get()[0] * canvas_hscoll_max, canvas.winfo_reqheight() / 2,
						text="Ctrl+Click a Note in Rip", fill=tk_rgb, tags="timbre_text")
				canvas.config(cursor="arrow")
			else:
				canvas.config(cursor="arrow")# Was "none" - but confusing to tell where to click

	def update_timbre_spotlight():
		if in_timbre_mode() and note_exists(timbre_note):
			duration = timbre_note.end-timbre_note.start
			view.spotlight(duration=duration, fade_in=duration/2, fade_out=duration/2, volume=40,
				source_note=timbre_note, source_time=timbre_note.start+duration/2)
		else:
			view.spotlight(source_note=None, source_time=-1)

	def update_selection_marker():
		canvas.delete("selection")
		if region_selected or selecting_region:
			tk_rgb = '#ffffff'
			if selection_slice_1 == 0 and selection_slice_0 >= 1:
				# Show line
				canvas.create_line(
					(selection_slice_0 - 1) * slice_width,
					canvas.winfo_reqheight() - (min(selection_harmonic_0, selection_harmonic_1) - 1) * harmonic_height - 1,
					(selection_slice_0 - 1) * slice_width,
					canvas.winfo_reqheight() - MAX_HARMONIC_MULTIPLE * harmonic_height - 0,
					fill=tk_rgb, width=pixel_scale(), tags="selection")
				tk_rgb_h = '#808080'
				canvas.create_line(
					(selection_slice_0 - 1) * slice_width - pixel_scale(),
					canvas.winfo_reqheight() - (min(selection_harmonic_0, selection_harmonic_1) - 1) * harmonic_height - 1,
					(selection_slice_0 - 1) * slice_width - pixel_scale(),
					canvas.winfo_reqheight() - MAX_HARMONIC_MULTIPLE * harmonic_height - 0,
					fill=tk_rgb_h, width=pixel_scale(), tags="selection")
				canvas.create_line(
					(selection_slice_0 - 1) * slice_width + pixel_scale(),
					canvas.winfo_reqheight() - (min(selection_harmonic_0, selection_harmonic_1) - 1) * harmonic_height - 1,
					(selection_slice_0 - 1) * slice_width + pixel_scale(),
					canvas.winfo_reqheight() - MAX_HARMONIC_MULTIPLE * harmonic_height - 0,
					fill=tk_rgb_h, width=pixel_scale(), tags="selection")
			else:
				# Show rectangle
				canvas.create_rectangle(
					(min(selection_slice_0, selection_slice_1) - 1) * slice_width,
					canvas.winfo_reqheight() - (min(selection_harmonic_0, selection_harmonic_1) - 1) * harmonic_height - 1,
					max(selection_slice_0, selection_slice_1) * slice_width - 1,
					canvas.winfo_reqheight() - (max(selection_harmonic_0, selection_harmonic_1)) * harmonic_height - 0,
					outline=tk_rgb, width=pixel_scale(), tags="selection")
			set_cursor()
				
	def time_string(seconds):
		# Return a string showing seconds as m:ss.ms
		ms = int(seconds * 100 % 100)
		ss = int(seconds % 60)
		m = int(seconds / 60)
		return "%d:%02d.%02d" % (m, ss, ms)
		
	def calc_harmonic_frequency(fundamental, inharmonicity, harmonic):
		# Calculate frequency of a harmonic given the fundamental and inharmonicity
		if inharmonicity > 0:
			return fundamental * harmonic * (1 + inharmonicity * (harmonic * harmonic - 1))
		else:
			return fundamental * harmonic
	
	def canvas_motion(event: Event):
		nonlocal edit_note
		nonlocal editing_note
		nonlocal canvas_spotlight
		nonlocal canvas_spotlight_fade_in
		nonlocal canvas_spotlight_fade_out
		nonlocal selection_harmonic_0, selection_slice_0, selection_harmonic_1, selection_slice_1, selecting_region
		nonlocal click_x, click_y
		
		#if show_adjusted.get(): return
		
		if note_exists(edit_note) and slice_width > 0:
			this_harmonic, this_slice = harmonic_and_slice_for_event(event)
			time = edit_note.time_at(position=this_slice) + edit_note.slice_duration / 2
			
			# Update displayed frequency and time for harmonic/slice
			if this_slice <= edit_note.number_of_slices:
				if this_harmonic <= edit_note.number_of_harmonics:
					number_of_layers = edit_note.slices.harmonic(this_harmonic).number_of_layers
				else:
					number_of_layers = 0
				# Harmonic
				frequency_static_text.config(text="Harmonic")
				if this_harmonic <= edit_note.number_of_harmonics and number_of_layers > 0:
					total_frequency = 0
					total_db = 0
					total_loudness = 0
					for layer in range(1, number_of_layers + 1):
						layer_slice = edit_note.slices.harmonic(this_harmonic).layer(layer).slice(this_slice)
						this_loudness = layer_slice.volume.loudness
						total_frequency += layer_slice.pitch.frequency * this_loudness
						total_loudness += this_loudness
					if total_loudness:
						total_frequency /= total_loudness
					else:
						total_frequency = edit_note.slices.harmonic(this_harmonic).layer(1).slice(this_slice).pitch.frequency
					total_db = loudness(loudness=total_loudness).db
					if total_frequency == 0.0:
						# Try calculating from fundamental
						total_frequency = calc_harmonic_frequency(edit_note.slice(this_slice).pitch.frequency, edit_note.inharmonicity, this_harmonic)
					if total_frequency == 0.0:
						frequency_text.config(text="%d" % this_harmonic)
					elif total_frequency >= 1000.0:
						frequency_text.config(text="%d  ( %.2f kHz )" % (this_harmonic, total_frequency / 1000))
					else:
						frequency_text.config(text="%d  ( %.1f Hz )" % (this_harmonic, total_frequency))
					db_text.config(text="%d dB" % (total_db))
				else:
					# Try calculating frequency from fundamental
					total_frequency = calc_harmonic_frequency(edit_note.slice(this_slice).pitch.frequency, edit_note.inharmonicity, this_harmonic)
					if total_frequency == 0.0:
						frequency_text.config(text="%d" % this_harmonic)
					elif total_frequency >= 1000.0:
						frequency_text.config(text="%d  ( %.2f kHz )" % (this_harmonic, total_frequency / 1000))
					else:
						frequency_text.config(text="%d  ( %.1f Hz )" % (this_harmonic, total_frequency))
					db_text.config(text="-180 dB")
				
				# Time Slice
				time_static_text.config(text="Time Slice")
				time_text.config(text="%d  ( %s )" % (this_slice, time_string(edit_note.start + edit_note.time_at(this_slice))))
				# Update spotlight so can see where we are on note in Rip
				using_palette, this_duration, this_fade_in, this_fade_out = get_spotlight_info()
				view.spotlight(duration=this_duration, fade_in=this_fade_in, fade_out=this_fade_out,
					source_note=edit_note, source_time=edit_note.start + edit_note.time_at(this_slice),
					volume=100)
			else:
				frequency_static_text.config(text="")
				frequency_text.config(text="")
				db_text.config(text="")
				time_static_text.config(text="")
				time_text.config(text="")
		else:
			show_note(edit_note, None)
			return

		if selecting_region:
			# Moved far enough yet?
			if abs(click_x - event.x) >= 4 or abs(click_y - event.y) >= 4:
				# Set so always comes here once moved mouse far enough
				click_x = click_y = -999999
				# Draw selection marker
				selection_harmonic_1, selection_slice_1 = this_harmonic, this_slice
				update_selection_marker()
			
		else:
			if editing_note:
				# Perform edit
				updated_region = apply_edit(time, this_harmonic)
				if updated_region is not None:
					# Show updated note
					show_note(edit_note, updated_region)
					
			# Draw spotlight (if necessary)
			draw_spotlight(this_harmonic, time)
					
	def canvas_leave(event: Event):
		if note_exists(edit_note):
			canvas.delete("spotlight")
			db_text.config(text="")
			frequency_text.config(text="")
			frequency_static_text.config(text="")
			time_text.config(text="")
			time_static_text.config(text="")
		view.spotlight(source_note=None, source_time=-1)
			
	def clear_selection():
		nonlocal region_selected
		region_selected = False
		canvas.delete("selection")
		update_selection_level()
			
	def set_selection():
		nonlocal region_selected
		region_selected = True
		if selection_slice_range() is None:
			region_selected = False
			canvas.delete("selection")
		update_selection_level()
		
	def setup_transfer_note():
		nonlocal transfer_note
		if transfer_possible() and remove_to_other.get() == 1:
			# Does a note already exist?
			transfer_note = None
			for note in edit_rip.time_range(edit_note.start, edit_note.end).notes:
				if note != edit_note and note.start == edit_note.start and note.end == edit_note.end and \
					note.slice(1).pitch.frequency == edit_note.slice(1).pitch.frequency:
					transfer_note = note
					break
			if transfer_note is None:
				# Create silent copy of edit_note
				transfer_note = edit_note.copy_to()
				transfer_note.volume.amplitude = 0
				# Set to instrument name with (Removed) appended so easily selectable afterwards
				transfer_note.instrument = transfer_note.instrument + " (Removed)"
	
	def canvas_mouse_click(event: Event):
		nonlocal last_edit_time, last_edit_harmonic
		nonlocal editing_note
		nonlocal edit_note_volume
		nonlocal source_note
		nonlocal edit_note
		nonlocal region_selected
		nonlocal edit_anchor_slice	
		
		# Showing adjusted?
		#if show_adjusted.get():
		#	show_adjusted.set(0)
		#	show_adjusted_button.config(image=show_adjusted_image)
		#	show_note(edit_note, None)
		#	return
		
		# If selection mode?
		mode = current_editmode()
		if mode == selection_mode:
			canvas_mouse_select_region(event)
			return
			
		# Ensure playback stopped
		# NB We don't want looped playback to be stopped by this, so removed and stops on drawing anyway if not looping
		#if edit_rip is not None: edit_rip.stop()
		
		if note_exists(edit_note):
			
			# Slice modes require slice to be set
			if in_slice_mode() and (anchor_slice < 1 or anchor_slice > edit_note.number_of_slices): return
			
			# Timbre modes require timbre note to be set
			if in_timbre_mode():
				if not note_exists(timbre_note): return
				# Ensure it's not the same as the note being edited either
				if timbre_note == edit_note:
					ripx.pop_up("It is not possible to paint the selected timbre note with itself")
					return
					
			# Set up transfer note
			setup_transfer_note()
			
			# Edit slice anchor (for clone from slice mode)
			edit_anchor_harmonic, edit_anchor_slice = harmonic_and_slice_for_event(event)
				
			# Remember note and click time
			last_edit_time = None
			last_edit_harmonic = None
			
			# Set what to paint from Sound Palette (can be None)
			source_note = None
			edit_note_volume = db_adjustment()
			
			# Check both percussion or both harmonic
			if mode == palette_mode:
				if source_note is None:
					ripx.pop_up("Sound Palette sound not found - please select another sound")
					return
				elif source_note.percussion != edit_note.percussion:
					ripx.pop_up("It is not possible to paint notes with unpitched sound, and vice versa")
					return
					
			# Start editing the clicked note
			edit_note.edits_start()
			editing_note = True
			
			# Perform initial edit
			canvas.delete("spotlight")
			#clear_selection()
			canvas_motion(event)
		else:
			show_note(edit_note, None)
	
	click_x = click_y = 0
	def canvas_mouse_select_region(event: Event):
		nonlocal click_x, click_y
		nonlocal selection_harmonic_0, selection_slice_0, selection_harmonic_1, selection_slice_1, selecting_region, region_selected
		# Set up selection
		click_x = event.x
		click_y = event.y
		canvas.delete("spotlight")
		clear_selection()
		selecting_region = True
		selection_harmonic_0, selection_slice_0 = harmonic_and_slice_for_event(event)
		selection_harmonic_1, selection_slice_1 = 0, 0

	def canvas_mouse_ctrl_click(event: Event):
		#if not view.has_control: return
		nonlocal anchor_slice
		if in_slice_mode():
			# Set slice anchor
			anchor_harmonic, anchor_slice = harmonic_and_slice_for_event(event)
			update_slice_anchor()
			
	def end_edit():
		nonlocal editing_note
		edit_note.edits_end()
		editing_note = False
		update_slice_anchor()
		if show_adjusted.get(): show_note(edit_note, None)# Re-show note as filters may affect slices/harmonics not touched
				
	def canvas_mouse_release(event: Event):
		nonlocal edit_note
		nonlocal editing_note
		nonlocal selection_harmonic_0, selection_slice_0, selection_harmonic_1, selection_slice_1, selecting_region, region_selected
		
		if not note_exists(edit_note): return
		
		mode = current_editmode()
		if selecting_region or mode == selection_mode:
			selecting_region = False
			# If mouse not moved, select all to play
			if selection_harmonic_1 == 0:
				selection_harmonic_0 = 1
				selection_harmonic_1 = MAX_HARMONIC_MULTIPLE
				selection_slice_1 = 0
				set_selection()
				show_note(edit_note, None)
				set_cursor()
				return
			set_selection()
			# Play selection
			if region_selected: play()
			set_cursor()
		
		elif editing_note:
			# End edit on note
			end_edit()
			# Play note
			play()
			
	def canvas_esc_pressed(event: Event):
		nonlocal edit_note, editing_note, selecting_region
		nonlocal playback_rip
		
		if editing_note:
			# Cancel edit
			end_edit()
			return "break"
			
		if selecting_region:
			selecting_region = False
			clear_selection()
			return "break"

		if region_selected and edit_rip.playback_time is None and (not playback_rip or playback_rip is None or playback_rip.playback_time is None):
			clear_selection()
			return "break"

		# If not handled, must always signal to RipX to handle Esc presses
		return "to_ripx"
		
	def window_delete_pressed(event: Event):
		#if not view.has_control: return
		selected_slice_range = selection_slice_range()
		if selected_slice_range is not None:
			# Silence region
			selected_slice_range.volume.amplitude = 0.0
			show_note(edit_note, None)
			play()

	def window_updown_pressed(event: Event):
		#if not view.has_control: return
		selected_slice_range = selection_slice_range()
		if selected_slice_range is not None:
			# Adjust volume of region
			if event.keysym == "Up":
				selected_slice_range.volume += 2 # dB
			else:
				selected_slice_range.volume -= 2 # dB
			show_note(edit_note, None)
			play()
			return "break" # Prevent combo box itself getting event to show menu

	def window_selectall_pressed(event: Event):
		#if not view.has_control: return
		nonlocal selection_harmonic_0, selection_slice_0, selection_harmonic_1, selection_slice_1, selecting_region, region_selected
		if note_exists(edit_note):
			selection_harmonic_0 = 1
			selection_harmonic_1 = edit_note.number_of_harmonics
			selection_slice_0 = 1
			selection_slice_1 = edit_note.number_of_slices
			selecting_region = False
			set_selection()
			update_selection_marker()
		return "break"
			
	previous_edit_mode = None
	alt_down = False
	def window_alt_pressed(event: Event):
		nonlocal previous_edit_mode, alt_down
		if note_exists(edit_note) and not alt_down:
			# Change to selection mode temporarily
			previous_edit_mode = tool_setting.get()
			canvas.delete("spotlight")
			set_tool(selection_mode)
			alt_down = True
		return "break"
			
	def window_alt_released(event: Event):
		nonlocal previous_edit_mode, alt_down
		alt_down = False
		if note_exists(edit_note) and previous_edit_mode is not None:
			# Change back to original mode
			set_tool(previous_edit_mode)
		return "break"
		
	def mouse_ctrl_click(event: ViewEvent):
		#if not view.has_control: return
		nonlocal timbre_note
		if in_timbre_mode():
			if event.note is not None:
				# Remember note for using timbre
				timbre_note = event.note
				update_timbre_text()
				timbre_note.play()
				update_timbre_spotlight()
				return
		return "to_ripx"
		
	# Create callback to handle clicks on canvas
	tk_rgb = "#%02x%02x%02x" % (2 * 0x45, 2 * 0x61, 2 * 0x79)
	canvas.create_rectangle(0, 0, canvas.winfo_reqwidth(), canvas.winfo_reqheight(), fill="#000000")
	canvas.create_text(canvas.winfo_reqwidth() / 2 + canvas_hscroll.get()[0] * canvas_hscoll_max, canvas.winfo_reqheight() / 2,
		text="Please Wait", fill=tk_rgb)
	canvas.bind("<Button-1>", canvas_mouse_click)
	if platform.system() == "Darwin": # Mac OS X
		canvas.bind("<Command-Button-1>", canvas_mouse_ctrl_click)
		window.winfo_toplevel().bind("<Command-a>", window_selectall_pressed)
		window.winfo_toplevel().bind("<Command-x>", window_cut_pressed)
		window.winfo_toplevel().bind("<Command-c>", window_copy_pressed)
		window.winfo_toplevel().bind("<Command-v>", window_paste_pressed)
	else:
		canvas.bind("<Control-Button-1>", canvas_mouse_ctrl_click)
		window.winfo_toplevel().bind("<Control-a>", window_selectall_pressed)
		window.winfo_toplevel().bind("<Control-x>", window_cut_pressed)
		window.winfo_toplevel().bind("<Control-c>", window_copy_pressed)
		window.winfo_toplevel().bind("<Control-v>", window_paste_pressed)
	canvas.bind("<Motion>", canvas_motion)
	canvas.bind("<Leave>", canvas_leave)
	canvas.bind("<ButtonRelease-1>", canvas_mouse_release)
	window.winfo_toplevel().bind("<Key-BackSpace>", window_delete_pressed)
	window.winfo_toplevel().bind("<Key-Delete>", window_delete_pressed)
	window.winfo_toplevel().bind("<Key-Up>", window_updown_pressed)
	window.winfo_toplevel().bind("<Key-Down>", window_updown_pressed)
	window.winfo_toplevel().bind("<Key-Alt_L>", window_alt_pressed)
	window.winfo_toplevel().bind("<Key-Alt_R>", window_alt_pressed)
	window.winfo_toplevel().bind("<KeyRelease-Alt_L>", window_alt_released)
	window.winfo_toplevel().bind("<KeyRelease-Alt_R>", window_alt_released)
	window.winfo_toplevel().bind("<Key-Up>", window_updown_pressed)
	window.winfo_toplevel().bind("<Key-Down>", window_updown_pressed)
	window.winfo_toplevel().bind("<space>", play)
	def window_select_tool(event: Event):
		if event.char == '0': set_tool(9)
		elif event.keysym == 'exclam': set_tool(10)
		#elif event.keysym == 'quotedbl' or event.keysym == 'at': set_tool(11)
		#elif event.keysym == 'numbersign' or event.keysym == 'sterling' or event.keysym == 'currency': set_tool(12)
		#elif event.keysym == 'dollar': set_tool(13)
		else: set_tool(int(event.char) - int('1'))
	window.winfo_toplevel().bind("<Key-1>", window_select_tool)
	window.winfo_toplevel().bind("<Key-2>", window_select_tool)
	window.winfo_toplevel().bind("<Key-3>", window_select_tool)
	window.winfo_toplevel().bind("<Key-4>", window_select_tool)
	window.winfo_toplevel().bind("<Key-5>", window_select_tool)
	window.winfo_toplevel().bind("<Key-6>", window_select_tool)
	window.winfo_toplevel().bind("<Key-7>", window_select_tool)
	window.winfo_toplevel().bind("<Key-8>", window_select_tool)
	window.winfo_toplevel().bind("<Key-9>", window_select_tool)
	window.winfo_toplevel().bind("<Key-0>", window_select_tool)
	window.winfo_toplevel().bind("<exclam>", window_select_tool)
	#window.winfo_toplevel().bind("<quotedbl>", window_select_tool)
	#if platform.system() == "Darwin": # Mac OS X
	#	window.winfo_toplevel().bind("<at>", window_select_tool) 
	#window.winfo_toplevel().bind("<numbersign>", window_select_tool) # This and next 2 are the same button on different country keyboards
	#window.winfo_toplevel().bind("<sterling>", window_select_tool)
	#window.winfo_toplevel().bind("<currency>", window_select_tool)
	#window.winfo_toplevel().bind("<dollar>", window_select_tool)
	view.bind("<Control-Button-1>", mouse_ctrl_click)
	# If we want Esc to be processed to enable undo we can bind to view
	# as Escape key presses get passed down from the tkinter window
	view.bind("<Key-Escape>", canvas_esc_pressed)

	# Show first selected pitched note in editor
	if view.rip is not None:
		for note in view.rip.selected_notes:
			if not note.percussion:
				edit_rip = view.rip
				create_reset_note(note)
				edit_note = note
				# If already playing set as playback rip
				if edit_rip.playback_time is not None:
					playback_rip = edit_rip
					playback_starttime = playback_rip.playback_time
					play_update()
					window.after(40, play_update)
					play_button.config(image=stop_image)
				break
	#view.take_control()
	update_layers()
	view.spotlight(source_note=None)
	if edit_note is None: show_note(None, None)
	set_tool(tool_setting.get())
	# Set main HM editor mode to regular editing mode since less confusing clicking on notes
	view.set_edit_mode(mode=MODE_MOVE_RESIZE)
