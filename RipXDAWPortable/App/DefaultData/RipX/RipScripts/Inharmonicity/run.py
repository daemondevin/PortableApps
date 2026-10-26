"""
Description: Set inharmonicity level to selected notes
Category: Effects
Shortcut:
Level: Beginner
Version: 1.10
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
	
	# Load settings and set defaults
	settings = Settings()
	settings.add("inharmonicity", 0.0)

	window = ripx.add_tk_window(sticky="NWE")
	pad_x = 6 * pixel_scale()
	pad_y = 4 * pixel_scale()
	window.add_label(text="Inharmonicity increases the spacing between harmonics.").grid(row = 0, column = 0, padx=12, pady=8)
	window.add_label(text="Higher settings create more metallic sounds.").grid(row = 1, column = 0, padx=12, pady=0)
	frame = window.add_label_frame(text=" Inharmonicity ")
	frame.grid(column=0, row=2, padx=12, pady=16)
	
	def inharmonicity_changed(string):
		inharmonicity_label['text'] = "%d %%" % (inharmonicity.get() * 1000)
	frame.add_label(text="None").grid(row=0, column=0, sticky="w", padx=16, pady=16)
	inharmonicity_scale = frame.add_scale(from_=0.0, to=0.1, orient=HORIZONTAL,
		variable=inharmonicity, command=inharmonicity_changed, length=132*pixel_scale(),
		tooltip="Drag slider to adjust inharmonicity")
	inharmonicity_scale.grid(row=0, column=1, sticky="w", padx=0, pady=16)
	frame.add_label(text="High").grid(row=0, column=2, sticky="w", padx=16, pady=16)
	inharmonicity_label = frame.add_label(text=str(inharmonicity.get()))
	inharmonicity_label.configure(anchor="center")
	inharmonicity_label.grid(row=1, column=1, sticky="we", padx=16, pady=8)
	#frame.add_label(text="").grid(row = 2, column = 0, padx=12, pady=0)
	inharmonicity_changed("")

	def set_inharmonicity(event: Event):
		rip = ripx.current_view.rip
		if rip is None:
			ripx.pop_up("Inharmonicity requires a rip to be loaded")
			return
		
		for note in rip.selected_notes:
			note.inharmonicity = float(inharmonicity.get())
					
	# Add Apply button
	apply_button = window.add_button(text=" Apply Inharmonicity ")
	apply_button.grid(column=0, row=3, padx=16, pady=pad_y, sticky=(E))
	apply_button.bind("<Button-1>", set_inharmonicity)
	
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

