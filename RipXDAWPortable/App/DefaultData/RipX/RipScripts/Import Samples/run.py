"""
Description: Import sample files into Sound Palette
Category: Tools
Shortcut: 
Level: Beginners
Version: 1.10
Copyright:	(c) Hit'n'Mix Ltd 2019-2023
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
	settings.add("sample_folder_name", "")
	settings.add("ripper_setting", "Pitched")
	
	global samples_file_names
	samples_file_names = StringVar()
	samples_file_names.set("")
	sound_palette_name = None
	files = ""

	if platform.system() == "Darwin": # Mac OS X
		filetypes = [ ("Audio Files", "*.wav *.mp3 *.flac *.ogg *.oga *.aif *.aiff") ]
	else:
		filetypes = [ ("Audio Files", "*.wav *.mp3 *.flac *.ogg *.oga *.cda") ]

	# Set default folder
	if sample_folder_name.get() == "" and platform.system() != "Darwin":
		sample_folder_name.set(os.environ['USERPROFILE'])
				
	# Load button images into global variables to ensure not garbage collected and removed
	global photos
	photos = []
	def add_image(filename):
		global photos
		im = Image.open(ripscript_path(filename))
		scale = pixel_scale() * 0.25 # We are provided x2 sized bitmaps
		im = im.resize((int(im.width * scale), int(im.height * scale)), Image.ANTIALIAS)
		photos.append(ImageTk.PhotoImage(im))
	add_image("add_x2.png")
	add_image("folder_x2.png")

	## Select samples
	file_frame = window.add_label_frame(text=" 1)  Choose Samples ")
	file_frame.grid(column=0, row=0, padx=pad_x, pady=pad_y, sticky="we")

	# Samples display and selection button
	folder_entry = file_frame.add_entry(textvariable=samples_file_names, state="readonly", width=24)
	folder_entry.grid(column=1, row=1, padx=pad_x, pady=pad_y, sticky="we")
	folder_button = file_frame.add_button(image=photos[1], text="Samples... ", compound="left")
	folder_button.grid(column=0, row=1, padx=pad_x, pady=pad_y, sticky="we")
	selecting_files = False
	def select_files(event: Event):
		nonlocal selecting_files, files
		if selecting_files: return
		selecting_files = True
		
		files = filedialog.askopenfilenames(initialdir=sample_folder_name.get(), title="Select Samples To Import", filetypes=filetypes)
		if files is not None and len(files) > 0 and files[0] != "":
			sample_folder_name.set(os.path.dirname(files[0]))
			if len(files) > 1:
				samples_file_names.set(os.path.basename(files[0]) + " & more")
			else:
				samples_file_names.set(os.path.basename(files[0]))

		selecting_files = False
	folder_button.bind("<Button-1>", select_files)

	## Settings
	settings_frame = window.add_label_frame(text=" 2)  Import Settings ")
	settings_frame.grid(column=0, row=3, padx=pad_x, pady=pad_y, sticky="we")
	# Ripper Setting
	label = settings_frame.add_label(text="Type", anchor="w")
	label.grid(row=1, column=1, sticky="w", padx=pad_x)
	ripper_setting_combo = settings_frame.add_combo_box(values=ripper_settings_strings, textvariable=ripper_setting, state="readonly")
	ripper_setting_combo.grid(row=1, column=2, columnspan=5, padx=0, pady=pad_y, sticky="w")

	def add_sound_from_note_group(note_group: NoteGroup, rip: Rip, category):
		
		## Remove layers less than this dB from peak average harmonic
		reduce_layers_db = -50
		
		## Maximum duration of sample in seconds
		max_sound_duration = 20

		if note_group is None or note_group.end < 0 or note_group.end == note_group.start:
			ripx.pop_up(message="No audio found")
			return
		
		# Create a new note group with notes we want
		# First add group for all notes in time region
		# If individual notes selected, not a time selection, so only keep selected note
		end_time = min(max_sound_duration, note_group.end) # Limit to maximum sample duration
		sound_group = rip.note_group(end=end_time)
		if sound_group is None or len(sound_group) == 0:
			ripx.pop_up(message="No audio found (2)")
			return

		# Copy notes to a temporary ripcut to merge harmonic notes and then group with percussive sounds
		temp_ripcut = rip.new_ripcut(name="Import Samples Workspace")
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
			
		if main_note is None or not main_note:
			ripx.pop_up(message="There was a problem importing the samples, please try again")
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
				if instrument is None and len(palette.ripcuts) >= MAX_RIPCUTS_PER_RIP:
					ripx.pop_up(message="Maximum Samples per Sound Palette is " + str(MAX_RIPCUTS_PER_RIP))
			if instrument is not None:
				# Clear any existing notes for importing samples, which only allow one note per instrument
				instrument.notes.delete()
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
				
	def sample_ripped(rip: Rip):
		ripx.interact(message="Importing Sample", progress=0.1)
		# Set instrument to name of file
		for note in rip.notes:
			note.instrument = rip.name
		ripx.interact(message="Importing Sample", progress=0.2)
		# Add to Sound Palette
		add_sound_from_note_group(rip.notes, rip, sound_palette_name)
		ripx.interact(message="Importing Sample", progress=0.95)
		# Delete rip
		rip.delete()
		ripx.interact(message="Importing Sample", progress=1.0)

	# Import samples button and functionality
	import_button = window.add_button(image=photos[0], text="Import ", compound="left")
	import_button.grid(column=0, row=4, padx=pad_x, pady=pad_y, sticky=(E))
	importing = False
	def import_samples(event: Event):
		nonlocal importing, files, sound_palette_name
		
		if importing: return
		importing = True
		
		if len(files) == 0:
			ripx.pop_up("Please select samples first")
			importing = False
			return

		# Save state
		settings.save()

		# Import samples
		file_count = 0
		for file in files:
			# Set Sound Palette name from the parent folder name
			sound_palette_name=os.path.basename(os.path.dirname(file))
			if sound_palette_name is None or len(sound_palette_name) < 1:
				sound_palette_name = "Imported Samples"
			ripx.rip_file(file=file, rip_handler=sample_ripped, ripper_setting=ripper_settings[ripper_settings_strings.index(ripper_setting.get())])
			file_count += 1
			if file_count >= MAX_RIPCUTS_PER_RIP:
				break

		#window.winfo_toplevel().destroy() # Stay open to add more
			
		if file_count == 1:
			ripx.pop_up(5, "\n1 Sample Importing.\n\nIt will appear in the\nSound panel when ready.\n")
		else:
			ripx.pop_up(5, "\n" + str(file_count) + " Samples Importing.\n\nThey will appear in the\nSound panel when ready.\n")

		importing = False
			
	def import_samples_cancel(event: Event):
		ripx.reset_vst_instrument()
		settings.save()
		window.winfo_toplevel().destroy()
		return "break"
	
	# Reset VST if window closed
	def window_closed(event: Event):
		if event.widget == window: # Otherwise occurs for every widget in window
			ripx.reset_vst_instrument()
			settings.save()
	
	window.winfo_toplevel().bind("<Destroy>", window_closed)
	import_button.bind("<Button-1>", import_samples)
	# Also press Enter to Import?
	#window.winfo_toplevel().bind("<Key-Return>", import_samples)
	# Cancel window
	window.winfo_toplevel().bind("<Key-Escape>", import_samples_cancel)
