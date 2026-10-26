"""
Description: Import VST instrument samples into Sound Palette
Category: Tools
Shortcut:
Level: Beginners
Version: 1.15
Copyright:	(c) Hit'n'Mix Ltd 2022-2023
Author:		Martin Dawe
"""

import os
import platform
from tkinter import filedialog
from PIL import Image, ImageTk

def ripscript():
			
	# Create window
	window = ripx.add_tk_window(sticky='NSWE')
	pad_x = 8 * pixel_scale()
	pad_y = 6 * pixel_scale()

	# ripper settings for type
	ripper_settings = [ 0xff05, 0 ]
	ripper_settings_strings = [ "Pitched", "Unpitched" ]

	# Load settings and set defaults
	settings = Settings()
	settings.add("vst_folder_name", "")
	settings.add("instrument_name", "VST3 Instrument") # Default WAV16
	settings.add("pitch_from", 36) # C2
	settings.add("pitch_to", 83) # B5
	settings.add("pitch_step", 1)
	settings.add("ripper_setting", "Pitched")
	
	global vst_file_name, pitch_from_string, pitch_to_string
	vst_file_name = StringVar()
	vst_file_name.set("")
	pitch_from_string = StringVar()
	pitch_to_string = StringVar()

	initialised_vst = False
				
	# Set default folder
	if vst_folder_name.get() == "":
		if platform.system() == "Darwin": # Mac OS X
			vst_folder_name.set("/Library/Audio/Plug-Ins/VST3")
		else:
			vst_folder_name.set("C:/Program Files/Common Files/VST3")
		
	# Load button images into global variables to ensure not garbage collected and removed
	global photos
	photos = []
	def add_image(filename):
		global photos
		im = Image.open(ripscript_path(filename))
		scale = pixel_scale() * 0.25 # We are provided x2 sized bitmaps
		im = im.resize((int(im.width * scale), int(im.height * scale)), Image.ANTIALIAS)
		photos.append(ImageTk.PhotoImage(im))
	add_image("play_x2.png")
	add_image("add_x2.png")
	add_image("vst_x2.png")

	## VST plug-in
	file_frame = window.add_label_frame(text=" 1)  Choose VST3 Plug-In ")
	file_frame.grid(column=0, row=0, padx=pad_x, pady=pad_y, sticky="we")

	# VST instrument display and selection button
	folder_entry = file_frame.add_entry(textvariable=vst_file_name, state="readonly", width=24)
	folder_entry.grid(column=1, row=1, padx=pad_x, pady=pad_y, sticky="we")
	folder_button = file_frame.add_button(image=photos[2], text="VST3 Plug-In... ", compound="left")
	folder_button.grid(column=0, row=1, padx=pad_x, pady=pad_y, sticky="we")
	selecting_vst = False
	def select_vst(event: Event):
		nonlocal initialised_vst, selecting_vst
		if selecting_vst: return
		selecting_vst = True
		if platform.system() == "Darwin": # Mac OS X
			vst_filetypes = "*.vst3 *.vst"
		else:
			vst_filetypes = "*.vst3 *.vst *.dll"
		file = filedialog.askopenfilename(initialdir=vst_folder_name.get(), title="Select VST3 Plug-In", \
			filetypes=[ ("VST3 Plug-Ins", vst_filetypes) ])
		if file != "":
			if ripx.init_vst_instrument(file):
				vst_file_name.set(os.path.basename(file))
				vst_folder_name.set(os.path.dirname(file))
				initialised_vst = True
			else:
				vst_file_name.set("")
				initialised_vst = False
		selecting_vst = False
	folder_button.bind("<Button-1>", select_vst)
	
	## Choose VST settings
	choose_vst_settings_frame = window.add_label_frame(text=" 2)  Select Instrument ")
	choose_vst_settings_frame.grid(column=0, row=1, padx=pad_x, pady=pad_y, sticky="we")
	entry = choose_vst_settings_frame.add_label(text="Set instrument and parameters in the VST3 Plug-In", anchor="w")
	entry.grid(column=0, row=0, padx=pad_x, pady=pad_y, sticky="we")

	## Instrument name
	instrument_frame = window.add_label_frame(text=" 3)  Enter Instrument Name: ")
	instrument_frame.grid(column=0, row=2, padx=pad_x, pady=pad_y, sticky="we")
	instrument_name_entry = instrument_frame.add_entry(textvariable=instrument_name, width=40, justify='center')
	instrument_name_entry.grid(column=0, row=0, padx=pad_x, pady=pad_y, sticky="we")

	## Settings
	settings_frame = window.add_label_frame(text=" 4)  Import Settings ")
	settings_frame.grid(column=0, row=3, padx=pad_x, pady=pad_y, sticky="we")
	#label = settings_frame.add_label(text="Pitch:", anchor="w")
	#label.grid(row=0, column=0, sticky="w", padx=pad_x)
	label = settings_frame.add_label(text="Every", anchor="w")
	label.grid(row=0, column=1, sticky="w", padx=pad_x)
	pitch_step_spinbox = settings_frame.add_spin_box(from_=1, to=12, increment=1, textvariable=pitch_step, width=2)
	pitch_step_spinbox.grid(row=0, column=2, padx=0, pady=pad_y)
	label = settings_frame.add_label(text="From", anchor="w")
	label.grid(row=0, column=3, sticky="w", padx=pad_x)
	def pitch_from_updated():
		pitch = midi_number(pitch_from.get())
		pitch_from_string.set(pitch.notation)
	pitch_from_updated()
	pitch_from_spinbox = settings_frame.add_spin_box(from_=24, to=97, increment=1, textvariable=pitch_from, width=3, command=pitch_from_updated)
	pitch_from_spinbox.grid(row=0, column=4, padx=0, pady=pad_y)
	pitch_from_label = settings_frame.add_label(textvariable=pitch_from_string, anchor="w", width=4)
	pitch_from_label.grid(row=0, column=5, padx=pad_x, pady=pad_y)
	label = settings_frame.add_label(text="To", anchor="w")
	label.grid(row=0, column=6, sticky="w")
	def pitch_to_updated():
		pitch = midi_number(pitch_to.get())
		pitch_to_string.set(pitch.notation)
	pitch_to_updated()
	pitch_to_spinbox = settings_frame.add_spin_box(from_=24, to=97, increment=1, textvariable=pitch_to, width=3, command=pitch_to_updated)
	pitch_to_spinbox.grid(row=0, column=7, padx=pad_x, pady=pad_y)
	pitch_to_label = settings_frame.add_label(textvariable=pitch_to_string, anchor="w", width=4)
	pitch_to_label.grid(row=0, column=8, padx=0, pady=pad_y)
	# Ripper Setting
	label = settings_frame.add_label(text="Type", anchor="w")
	label.grid(row=1, column=1, sticky="w", padx=pad_x)
	ripper_setting_combo = settings_frame.add_combo_box(values=ripper_settings_strings, textvariable=ripper_setting, state="readonly")
	ripper_setting_combo.grid(row=1, column=2, columnspan=5, padx=0, pady=pad_y, sticky="w")
	
	# Buttons frame
	buttons_frame = window.add_frame()
	buttons_frame.grid(column=0, row=4, sticky="e")

	# Audition VST button and functionality
	audition_button = buttons_frame.add_button(image=photos[0], text="Audition ", compound="left")
	audition_button.grid(column=0, row=4, padx=pad_x, pady=pad_y, sticky=(W))
	auditioning = False
	def audition_vst(event: Event):
		nonlocal auditioning, initialised_vst
		
		if auditioning: return
		auditioning = True

		if initialised_vst == False:
			ripx.pop_up("Please select a VST3 plug-in first")
			auditioning = False
			return
			
		if pitch_from.get() < 24 or pitch_from.get() > 97 or pitch_to.get() < 24 or pitch_to.get() > 97:
			ripx.pop_up("The pitch range must be between 24 and 97")
			auditioning = False
			return
			
		if pitch_to.get() < pitch_from.get():
			ripx.pop_up("The pitch range is not valid")
			auditioning = False
			return
	
		# Save state
		settings.save()	
		#window.winfo_toplevel().destroy() # Stay open to add more
		
		# Audition VST instrument
		ripx.audition_vst_instrument(pitch_from.get(), pitch_to.get())

		auditioning = False

	# Import VST button and functionality
	import_button = buttons_frame.add_button(image=photos[1], text="Import ", compound="left")
	import_button.grid(column=1, row=4, padx=pad_x, pady=pad_y, sticky=(E))
	importing = False
	def import_vst(event: Event):
		nonlocal importing, initialised_vst
		
		if importing: return
		importing = True

		if initialised_vst == False:
			ripx.pop_up("Please select a VST3 plug-in first")
			importing = False
			return
			
		if pitch_from.get() < 24 or pitch_from.get() > 97 or pitch_to.get() < 24 or pitch_to.get() > 97:
			ripx.pop_up("The pitch range must be between 24 and 97")
			importing = False
			return
			
		if pitch_to.get() < pitch_from.get():
			ripx.pop_up("The pitch range is not valid")
			importing = False
			return
	
		# Save state
		settings.save()	
		#window.winfo_toplevel().destroy() # Stay open to add more
		
		# Import VST instrument
		if ripx.import_vst_instrument(instrument_name.get(), pitch_from.get(), pitch_to.get(), \
			pitch_step.get(), ripper_settings[ripper_settings_strings.index(ripper_setting.get())]):		
			ripx.pop_up(5, "\nInstrument Importing.\n\nIt will appear in the\nSound panel when ready.\n")

		importing = False
			
	def import_vst_cancel(event: Event):
		ripx.reset_vst_instrument()
		settings.save()
		window.winfo_toplevel().destroy()
		return "break"
	
	# Reset VST if window closed
	def window_closed(event: Event):
		if event.widget == window: # Otherwise occurs for every widget in window
			ripx.reset_vst_instrument()
			settings.save()
		
	# Called by RipX when the VST plug-in is closed
	def reset_vst_callback():
		nonlocal initialised_vst
		initialised_vst = False
		vst_file_name.set("")
	ripscript.reset_vst_callback = reset_vst_callback
		
	window.winfo_toplevel().bind("<Destroy>", window_closed)
	import_button.bind("<Button-1>", import_vst)
	audition_button.bind("<Button-1>", audition_vst)
	# Also press Enter to Import?
	#window.winfo_toplevel().bind("<Key-Return>", import_vst)
	# Cancel window
	window.winfo_toplevel().bind("<Key-Escape>", import_vst_cancel)


