#! praat
#
# Copyright: 2019, R.J.J.H. van Son and the Netherlands Cancer Institute
# License: GNU AFFERO GENERAL PUBLIC LICENSE Version 3 or later
# email: r.j.j.h.vanson@gmail.com, r.v.son@nki.nl
# 
#     PseudonymizeSpeech.praat: Praat script to de-identify speech 
#     
#     Copyright (C) 2019  R.J.J.H. van Son and the Netherlands Cancer Institute
# 
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU Affero General Public License as published
#     by the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU Affero General Public License for more details.
# 
#     You should have received a copy of the GNU Affero General Public License
#     along with this program.  If not, see <https://www.gnu.org/licenses/>.
# 
label START
beginPause: "Select recordings"
	sentence: "Source", "TreasurePseudonymization.tsv"
	sentence: "Reference", "Treasure_SpeakerData.tsv"
	sentence: "Target Phi", "500 (Hz)"
	sentence: "Target Pitch", "120 (Hz)"
	sentence: "Target Rate", "3.8 (Syll/s)"
	sentence: "Target Directory", "pseudonimized"
	sentence: "Randomize bands", "F0, F3, F4, F5"
	sentence: "Randomize intensity", "F0, F3, F4, F5"
	boolean: "Remove_pauses", 0
clicked = endPause: "Help", "Continue", 2

if clicked = 1
	if fileReadable("Pseudonymize_Speech.man") 
		Read from file: "Pseudonymize_Speech.man"
	elsif fileReadable("ManPages/Pseudonymize_Speech.man")
		Read from file: "ManPages/Pseudonymize_Speech.man"
	endif
	goto START
endif


# Clean up input
target_Phi$ = replace$(target_Phi$, " (Hz)", "", 0)
target_Pitch$ = replace$(target_Pitch$, " (Hz)", "", 0)
target_Rate$ = replace$(target_Rate$, " (Syll/s)", "", 0)

debugON = 1
# If this name is <> "", save the table
saveReferenceTableName$ = "NEW_SpeakerDataTable.tsv"
call IntitalizeFormantSpace
speakerDataTable = Create Table with column names: "SpeakerData", 1, "Reference MedianPitch Phi Phi2 Phi3 Phi4 Phi5 ArtRate Duration"

# The Source input contains a control table
controlTable = -1
if index_regex(source$, "\.(tsv|csv)$")
	# The source file is a table
	if index_regex(source$, "\.tsv$")
		controlTable = Read Table from tab-separated file: source$
	else
		controlTable = Read from file: source$
	endif
	# Complete columns
	if controlTable > 0
		selectObject: controlTable
		Rename: "Control_Table"
		controlSource = Get column index: "Source"
		if controlSource <= 0
			# Column is invalid, stop
			Remove
			controlSource = -1
			exitScript: "Source Table does not contain a Source column: ", source$
		endif
		controlReference = Get column index: "Reference"
		if controlReference <= 0
			controlReference = 2
			Insert column: controlReference, "Reference"
		endif
		controlTarget_Phi = Get column index: "Target_Phi"
		if controlTarget_Phi <= 0
			controlTarget_Phi = 3
			Insert column: controlTarget_Phi, "Target_Phi"
		endif
		controlTarget_Pitch = Get column index: "Target_Pitch"
		if controlTarget_Pitch <= 0
			controlTarget_Pitch = 4
			Insert column: controlTarget_Pitch, "Target_Pitch"
		endif
		controlTarget_Rate = Get column index: "Target_Rate"
		if controlTarget_Rate <= 0
			controlTarget_Rate = 5
			Insert column: controlTarget_Rate, "Target_Rate"
		endif
		controlTarget_Directory = Get column index: "Target_Directory"
		if controlTarget_Directory <= 0
			controlTarget_Directory = 6
			Insert column: controlTarget_Directory, "Target_Directory"
		endif
	endif
else
	controlTable = Create Table with column names: "Control_Table", 1, "Source Reference Target_Phi Target_Pitch Target_Rate Target_Directory"
	controlSource = -1
	controlReference = 2
	controlTarget_Phi = 3
	controlTarget_Pitch = 4
	controlTarget_Rate = 5
	controlTarget_Directory = 6
endif

if index_regex(reference$, "\.(tsv|csv)$")
	# The reference file is a table
	if index_regex(reference$, "\.tsv$")
		.tmp = Read Table from tab-separated file: reference$
	else
		.tmp = Read from file: reference$
	endif
	if .tmp > 0
		selectObject: speakerDataTable
		Remove
		speakerDataTable = .tmp
		.tmp = 0
	endif
endif

if controlTable > 0
	selectObject: controlTable
	.numControlLines = Get number of rows
else
	exitScript: "Source Table is not found and could not be created"
endif

for .control to .numControlLines
	.currentTarget_PhiList [1] = -1
	.currentTarget_PitchList [1] = -1
	.currentTarget_RateList [1] = -1
	# Read values
	selectObject: controlTable
	.tmp$ = Get value: .control, "Source"
	currentSource$ = source$
	if .tmp$ <> "" and .tmp$ <> "-"
		currentSource$ = .tmp$;
	endif
	.tmp$ = Get value: .control, "Reference"
	currentReference$ = reference$
	if .tmp$ <> "" and .tmp$ <> "-"
		currentReference$ = .tmp$;
	endif
	.tmp$ = Get value: .control, "Target_Phi"
	currentTarget_Phi$ = target_Phi$
	if .tmp$ <> "" and .tmp$ <> "-"
		currentTarget_Phi$ = .tmp$;
	endif
	.tmp$ = Get value: .control, "Target_Pitch"
	currentTarget_Pitch$ = target_Pitch$
	if .tmp$ <> "" and .tmp$ <> "-"
		currentTarget_Pitch$ = .tmp$;
	endif
	.tmp$ = Get value: .control, "Target_Rate"
	currentTarget_Rate$ = target_Rate$
	if .tmp$ <> "" and .tmp$ <> "-"
		currentTarget_Rate$ = .tmp$;
	endif
	.tmp$ = Get value: .control, "Target_Directory"
	currentTarget_Directory$ = target_Directory$
	if .tmp$ <> "" and .tmp$ <> "-"
		currentTarget_Directory$ = .tmp$;
	endif
	
	# Handle source/reference files
	.wildcard$ = "*"
	if index(currentSource$, "*") > 0 or endsWith(currentSource$, "/")
		.wildcard$ = ""
	endif
	.sourceList = Create Strings as file list: "SourceList", currentSource$+.wildcard$
	.numSourceFiles = Get number of strings
	.sourceDirectory$ = replace_regex$(currentSource$, "/[^/]+$", "", 0)
	
	if index_regex(currentTarget_Phi$, "[;,]")
		.i = 1
		.phiTargets$ = currentTarget_Phi$
		.pitchTargets$ = currentTarget_Pitch$
		.rateTargets$ = currentTarget_Rate$
		while .phiTargets$ <> ""
			# Phi
			.current = extractNumber(.phiTargets$, "")
			.currentTarget_PhiList [.i] = .current
			.phiTargets$ = replace_regex$(.phiTargets$, "^[0-9\.]+[,;]?", "", 0)
			# Pitch
			.current = .currentTarget_PitchList [max(.i - 1, 1)]
			if .pitchTargets$ <> ""
				.current = extractNumber(.pitchTargets$, "")
			endif
			.currentTarget_PitchList [.i] = .current
			.pitchTargets$ = replace_regex$(.pitchTargets$, "^[0-9\.]+[,;]?", "", 0)
			# Rate
			.current = .currentTarget_RateList [max(.i - 1, 1)]
			if .rateTargets$ <> ""
				.current = extractNumber(.rateTargets$, "")
			endif
			.currentTarget_RateList [.i] = .current
			.rateTargets$ = replace_regex$(.rateTargets$, "^[0-9\.]+[,;]?", "", 0)
			# Next
			.i += 1
		endwhile
		.numTargets = .i - 1
	else
		.currentTarget_PhiList[1] = 'currentTarget_Phi$'
		.currentTarget_PitchList[1] = 'currentTarget_Pitch$'
		.currentTarget_RateList[1] = 'currentTarget_Rate$'
		.numTargets = 1
	endif
	
	for .f to .numSourceFiles
		selectObject: .sourceList
		.fileName$ = Get string: .f
		appendInfoLine: .sourceDirectory$+"/"+.fileName$
		.tmp = Read from file: .sourceDirectory$+"/"+.fileName$
		.nameSource$ = selected$()
		.sourceSound = Convert to mono
		Rename: .nameSource$
		selectObject: .tmp
		Remove
		
		# Remove pauses if desired
		if remove_pauses
			@remove_pauses: .sourceSound
			selectObject: .sourceSound
			Remove
			.sourceSound = remove_pauses.newSound
		endif
	
		currentRefName$ = currentReference$
		if currentReference$ = "-"
			currentRefName$ = currentSource$
		endif
		selectObject: speakerDataTable
		.dataRow = Search column: "Reference", currentRefName$
		if .dataRow <= 0
			if currentReference$ = "-"
				selectObject: .sourceSound
				.refRecording = Copy: "Reference"
			else
				.wildcard$ = "*"
				if index(currentReference$, "*") > 0 or endsWith(currentReference$, "/")
					.wildcard$ = ""
				endif
				.referenceList = Create Strings as file list: "ReferenceList", currentReference$+.wildcard$
				.refDirectory$ = replace_regex$(currentReference$, "[\\/][^\\/]+$", "", 0)
				.numRefFiles = Get number of strings
				.tmpList [1] = -1
				for .r to .numRefFiles
					selectObject: .referenceList
					.tmp$ = Get string: .r
					.tmpList [.r] = Read from file: .refDirectory$ + "/" + .tmp$
				endfor
				selectObject: .tmpList [1]
				if .numRefFiles > 1
					for .r from 2 to .numRefFiles
						plusObject: .tmpList [.r]
					endfor
				endif
				.tmp = Concatenate
				.refRecording = Convert to mono
				Rename: "Reference"
				selectObject: .referenceList, .tmp
				for .r from 1 to .numRefFiles
					plusObject: .tmpList [.r]
				endfor
				Remove
			endif
			
			# Calculate speaker characteristics
			# Get spreaker characteristics from the reference recording
			call vocalTractAndSpeakerMeasures .refRecording
			.medianPitch = vocalTractAndSpeakerMeasures.medianPitch
			.phi = vocalTractAndSpeakerMeasures.phi
			.phi2 = vocalTractAndSpeakerMeasures.phi2
			.phi3 = vocalTractAndSpeakerMeasures.phi3
			.phi4 = vocalTractAndSpeakerMeasures.phi4
			.phi5 = vocalTractAndSpeakerMeasures.phi5
			.referenceArtRate = vocalTractAndSpeakerMeasures.artRate
			.duration = vocalTractAndSpeakerMeasures.duration
			# Add to table
			selectObject: speakerDataTable
			.dataRow = Get number of rows
			# Add empty row
			Append row
			selectObject: speakerDataTable
			Set string value: .dataRow, "Reference", currentRefName$
			Set numeric value: .dataRow, "MedianPitch", .medianPitch
			Set numeric value: .dataRow, "Phi", .phi
			Set numeric value: .dataRow, "Phi2", .phi2
			Set numeric value: .dataRow, "Phi3", .phi3
			Set numeric value: .dataRow, "Phi4", .phi4
			Set numeric value: .dataRow, "Phi5", .phi5
			Set numeric value: .dataRow, "ArtRate", .referenceArtRate
			Set numeric value: .dataRow, "Duration", .duration
			
			selectObject: .refRecording
			Remove
		endif
		selectObject: speakerDataTable
		.currentSpeakerData ["MedianPitch"] = Get value: .dataRow, "MedianPitch"
		.currentSpeakerData ["Phi"] = Get value: .dataRow, "Phi"
		.currentSpeakerData ["Phi2"] = Get value: .dataRow, "Phi2"
		.currentSpeakerData ["Phi3"] = Get value: .dataRow, "Phi3"
		.currentSpeakerData ["Phi4"] = Get value: .dataRow, "Phi4"
		.currentSpeakerData ["Phi5"] = Get value: .dataRow, "Phi5"
		.currentSpeakerData ["ArtRate"] = Get value: .dataRow, "ArtRate"
		
		for .i to .numTargets
			.current_Phi = .currentTarget_PhiList[.i]
			.current_Pitch = .currentTarget_PitchList[.i]
			.current_Rate = .currentTarget_RateList[.i]
			@createPseudonymousSpeech: .sourceSound, speakerDataTable, .dataRow, .current_Phi, .current_Pitch, .current_Rate, randomize_bands$, randomize_intensity$
			.target = createPseudonymousSpeech.target
			.targetFilename$ = replace_regex$(.fileName$, "\.((?iwav|aifc))$", "_'.current_Phi:0'-'.current_Pitch:0'-'.current_Rate:1'.wav", 0)
			if currentTarget_Directory$ <> ""
				.k = 0
				.appx$ = ""
				while fileReadable(currentTarget_Directory$+"/"+.targetFilename$)
					.prevAppx$ = .appx$
					.k += 1
					.appx$ = "_'.k'"
					.targetFilename$ = replace_regex$(.targetFilename$, .prevAppx$+"(\.[^\.]+)$", .appx$+"\1", 0)
				endwhile
				nowarn Save as WAV file: currentTarget_Directory$+"/"+.targetFilename$
			endif
			appendInfoLine: .sourceDirectory$+"/"+.targetFilename$
			selectObject: .target
			Remove
		endfor
		
		selectObject: .sourceSound
		Remove
	endfor
	selectObject: .sourceList
	Remove
	
	if saveReferenceTableName$ <> ""
		selectObject: speakerDataTable
		Save as tab-separated file: saveReferenceTableName$
	endif

endfor
if saveReferenceTableName$ <> ""
	selectObject: speakerDataTable
	Save as tab-separated file: saveReferenceTableName$
endif

selectObject: controlTable
Remove

###############################################################
# 
# Pseudonymize recording
#
# .sourceSound:   Sound recording to pseudonymize
# .refRecording:  Speaker data of original speaker (array)
# .target_Phi:    Target vocal tract length in neutral F1 ("Phi" Hz)
# .target_Pitch:  Target Pitch to use in pseudonymized speech
# .target_Rate:   Target articulation rate to use
# .randomize_bands: Text string containing the bands F0 - F5 that
#                 are to get a random frequency offset.
#                 Example: "F0, F3, F4, F5"
# .randomize_intensity: Text string containing the bands F0 - F5 that
#                 are to get a random intensity offset.
#                 Example: "F0, F3, F4, F5"
# 
###############################################################

# Pseudonymize recording
procedure createPseudonymousSpeech .sourceSound .refData .dataRow .target_Phi .target_Pitch .target_Rate .randomize_bands$ .randomize_intensity$

	# Randomize formant bands individually
	# Parse Frequency band randomization
	for .i from 0 to 5
		modifyF'.i' = 0
		if index(.randomize_bands$, "F'.i'")
			modifyF'.i' = 1
			if index_regex(.randomize_bands$, "F'.i'\s*=\s*[-+]?\d")
				.band$ = replace_regex$(.randomize_bands$, "^.*(F'.i'\s*=\s*).*$", "\1", 0)
				modifyF'.i' = extractNumber(.randomize_bands$, .band$)
			endif
		endif
	endfor
	
	# Randomize intensity bands individually
	# Parse Intensity band randomization
	for .i from 0 to 5
		modifyInt'.i' = 0
		if index(.randomize_intensity$, "F'.i'")
			modifyInt'.i' = 1000
			if index_regex(.randomize_intensity$, "F'.i'\s*=\s*[-+]?\d")
				.band$ = replace_regex$(.randomize_intensity$, "^.*(F'.i'\s*=\s*).*$", "\1", 0)
				modifyInt'.i' = extractNumber(.randomize_intensity$, .band$)
			endif
		endif
	endfor

	# Get spreaker characteristics from the reference recording
	selectObject: .refData
	.medianPitch  = Get value: .dataRow, "MedianPitch"
	.phi  = Get value: .dataRow, "Phi"
	.phi2 = Get value: .dataRow, "Phi2"
	.phi3 = Get value: .dataRow, "Phi3"
	.phi4 = Get value: .dataRow, "Phi4"
	.phi5 = Get value: .dataRow, "Phi5"
	.referenceArtRate = Get value: .dataRow, "ArtRate"
	
	# # Use the articulation rate of the source
	# call segment_syllables -25 4 0.3 1 .sourceSound
	# .artRate = segment_syllables.articulationrate
	# selectObject: segment_syllables.textgridid
	# Remove
	
	# Use stored Art Rate
	.artRate = Get value: .dataRow, "ArtRate"
	
	# Change lower formants
	selectObject: .sourceSound
	.target = noprogress Change gender: 60, 600, .target_Phi / .phi, .target_Pitch, 1, .artRate / .target_Rate
	Scale intensity: 70.0
	Rename: "Pseudonymized"
	
	# Initialize
	for .i from 0 to 5
		# Set band frequency targets
		.target_Phi'.i' = -1;
		if modifyF0 > 1
			.target_Phi'.i' = modifyF'.i'
		elsif modifyF'.i'
			.target_Phi'.i' = randomUniform(.target_Phi - 75, .target_Phi + 75)
		endif
		
		# Set band intensity targets
		.set_Int'.i' = 70
		if modifyInt'.i' < 1000
			.set_Int'.i' = modifyInt'.i'
		elsif modifyInt'.i'
			.set_Int'.i' = 70 + randomUniform(-6, 12)
		endif
	endfor
	
	# Change F0 band
	if modifyF0 or modifyInt0
		selectObject: .sourceSound
		if modifyF0
			.intermediateSoundF0 = noprogress Change gender: 60, 600, .target_Phi0 / .phi, .target_Pitch, 1, .artRate / .target_Rate 
		else
			selectObject: .target
			.intermediateSoundF0 = Copy: "CleanCopy"
		endif
		Scale intensity: .set_Int0
		Rename: "IntermediatePseudonymizedF0"

		@replaceBand: .target, .intermediateSoundF0, 0, .target_Phi / 2
		
		selectObject: .target, .intermediateSoundF0
		Remove
		.target = replaceBand.target
		selectObject: .target
		Scale intensity: 70.0
		Rename: "Pseudonymized"
	endif

	# Change F1 band
	if modifyF1 or modifyInt1
		selectObject: .sourceSound
		if modifyF1
			.intermediateSoundF1 = noprogress Change gender: 60, 600, .target_Phi1 / .phi, .target_Pitch, 1, .artRate / .target_Rate 
		else
			selectObject: .target
			.intermediateSoundF1 = Copy: "CleanCopy"
		endif
		Scale intensity: .set_Int1
		Rename: "IntermediatePseudonymizedF1"

		@replaceBand: .target, .intermediateSoundF1, .target_Phi / 2, 2*.target_Phi
		
		selectObject: .target, .intermediateSoundF1
		Remove
		.target = replaceBand.target
		selectObject: .target
		Scale intensity: 70.0
		Rename: "Pseudonymized"
	endif
	
	# Change F2 band
	if modifyF2 or modifyInt2
		selectObject: .sourceSound
		if modifyF2
			.intermediateSoundF2 = noprogress Change gender: 60, 600, .target_Phi2 / .phi2, .target_Pitch, 1, .artRate / .target_Rate 
		else
			selectObject: .target
			.intermediateSoundF2 = Copy: "CleanCopy"
		endif
		Scale intensity: .set_Int2
		Rename: "IntermediatePseudonymizedF2"

		@replaceBand: .target, .intermediateSoundF2, 2*.target_Phi, 4*.target_Phi
		
		selectObject: .target, .intermediateSoundF2
		Remove
		.target = replaceBand.target
		selectObject: .target
		Scale intensity: 70.0
		Rename: "Pseudonymized"
	endif
	
	# Change F3 band
	if modifyF3 or modifyInt3
		selectObject: .sourceSound
		if modifyF3
			.intermediateSoundF3 = noprogress Change gender: 60, 600, .target_Phi3 / .phi3, .target_Pitch, 1, .artRate / .target_Rate 
		else
			selectObject: .target
			.intermediateSoundF3 = Copy: "CleanCopy"
		endif
		Scale intensity: .set_Int3
		Rename: "IntermediatePseudonymizedF3"

		@replaceBand: .target, .intermediateSoundF3, 4*.target_Phi, 6*.target_Phi
		
		selectObject: .target, .intermediateSoundF3
		Remove
		.target = replaceBand.target
		selectObject: .target
		Scale intensity: 70.0
		Rename: "Pseudonymized"
	endif
	
	# Change F4 band
	if modifyF4 or modifyInt4
		selectObject: .sourceSound
		if modifyF4
			.intermediateSoundF4 = noprogress Change gender: 60, 600, .target_Phi4 / .phi4, .target_Pitch, 1, .artRate / .target_Rate 
		else
			selectObject: .target
			.intermediateSoundF4 = Copy: "CleanCopy"
		endif
		Scale intensity: .set_Int4
		Rename: "IntermediatePseudonymizedF4"

		@replaceBand: .target, .intermediateSoundF4, 6*.target_Phi, 8*.target_Phi
		
		selectObject: .target, .intermediateSoundF4
		Remove
		.target = replaceBand.target
		selectObject: .target
		Scale intensity: 70.0
		Rename: "Pseudonymized"
	endif
	
	# Change F5 band
	if modifyF5 or modifyInt5
		selectObject: .sourceSound
		if modifyF5
			.intermediateSoundF5 = noprogress Change gender: 60, 600, .target_Phi5 / .phi5, .target_Pitch, 1, .artRate / .target_Rate 
		else
			selectObject: .target
			.intermediateSoundF5 = Copy: "CleanCopy"
		endif
		Scale intensity: .set_Int5
		Rename: "IntermediatePseudonymizedF5"

		@replaceBand: .target, .intermediateSoundF5, 8*.target_Phi, 20000
		
		selectObject:  .target, .intermediateSoundF5
		Remove
		.target = replaceBand.target
		selectObject: .target
		Scale intensity: 70.0
		Rename: "Pseudonymized"
	endif
	
	# Write values to screen
	printline Original- F0: '.medianPitch:0' Phi- F1-5: '.phi:0' F2: '.phi2:0' F3: '.phi3:0' F4: '.phi4:0' F5: '.phi5:0' Rate: '.artRate:1' 
	printline Targets- F0: '.target_Pitch:0' Phi- F1-5: '.target_Phi:0' F0: '.target_Phi0:0' F2: '.target_Phi2:0' F3: '.target_Phi3:0' F4: '.target_Phi4:0' F5 '.target_Phi5:0' Rate: '.target_Rate:1'

	selectObject: .target
endproc

###############################################################

procedure remove_pauses .sound
	.newSound = -1
	.margin = 0.01
	selectObject: .sound
	.duration = Get total duration
	.pauzes = To TextGrid (silences): 90, 0, -30, 0.1, 0.05, "", "sounding"
	.numSegment = Get number of intervals: 1
	for .i to .numSegment
		selectObject: .pauzes
		.label$ = Get label of interval: 1, .i
		if .label$ = "sounding"
			.start = Get start time of interval: 1, .i
			.end = Get end time of interval: 1, .i
			.start -= .margin
			if .start < 0
				.start = 0
			endif
			.end += .margin
			if .end > .duration
				.end = .duration
			endif
			selectObject: .sound
			.tmp = Extract part: .start, .end, "rectangular", 1.0, "no"
			if .newSound > 0
				selectObject: .newSound, .tmp
				.tmp2 = Concatenate
				selectObject: .newSound, .tmp
				Remove
				
				.newSound = .tmp2
			else
				.newSound = .tmp
			endif
		endif
	endfor
	selectObject: .pauzes
	Remove
	
	# Handle No-new sound file
	if .newSound <= 0
		selectObject: .sound
		.newSound = Copy: "NoPauses"
	endif
endproc

###############################################################

procedure vocalTractAndSpeakerMeasures .sound
	selectObject: .sound
	.duration = Get total duration
	Scale intensity: 70.0
	.formants = noprogress To Formant (robust): 0.01, 5, 5500, 0.025, 50, 1.5, 5, 1e-06
	
	call extract_speaker_characteristics: .sound .formants
	.medianPitch = extract_speaker_characteristics.medianF0
	.medianF2 = extract_speaker_characteristics.medianF2
	.medianF3 = extract_speaker_characteristics.medianF3
	.medianF4 = extract_speaker_characteristics.medianF4
	.medianF5 = extract_speaker_characteristics.medianF5
	
	# Determine all other parameters from the reference
	call segment_syllables -25 4 0.3 1 .sound
	.artRate = segment_syllables.articulationrate
	.syllableKernels = segment_syllables.textgridid
	.targetTier = 1
	
	@select_vowel_target: "F", .sound, .formants, .formants, .syllableKernels
	.vowelTier = select_vowel_target.vowelTier
	.targetTier = select_vowel_target.targetTier
	
	@estimate_Vocal_Tract_Length: .formants, .syllableKernels, .vowelTier
	.vocalTractLength = estimate_Vocal_Tract_Length.vtl
	.phi = estimate_Vocal_Tract_Length.phi
	
	.phi2 = .medianF2/3
	.phi3 = .medianF3/5
	.phi4 = .medianF4/7
	.phi5 = .medianF5/9
	
	
	selectObject: .formants, .syllableKernels
	Remove
endproc

###############################################################

procedure extract_speaker_characteristics .sound .formants
	selectObject: .sound
	.removeFormants = .formants
	if .formants <= 0
		.formants = noprogress To Formant (robust): 0.01, 5, 5500, 0.025, 50, 1.5, 5, 1e-06
	endif
	
	selectObject: .sound
	.pitch = noprogress To Pitch: 0, 75, 600
	.medianF0 = Get quantile: 0, 0, 0.50, "Hertz"
	.sdF0 = Get standard deviation: 0, 0, "Hertz"
	.quant90F0 = Get quantile: 0, 0, 0.90, "Hertz"
	.quant10F0 = Get quantile: 0, 0, 0.10, "Hertz"
	.spreadF0 = .quant90F0 - .quant10F0

	call segment_syllables -25 4 0.3 1 .sound
	.syllableKernels = segment_syllables.textgridid
	.targetTier = 1

	@select_vowel_target: "F", .sound, .formants, .formants, .syllableKernels
	.vowelTier = select_vowel_target.vowelTier
	.targetTier = select_vowel_target.targetTier

	@estimate_Vocal_Tract_Length: .formants, .syllableKernels, .vowelTier
	.vocalTractLength = estimate_Vocal_Tract_Length.vtl
	.phi = estimate_Vocal_Tract_Length.phi

	.sp$ = "F"
	if .phi < averagePhi_VTL [plotFormantAlgorithm$, "A"]
		.sp$ = "M"
	endif
	# Watch out .sp$ must be set BEFORE the scaling
	.vtlScaling = averagePhi_VTL [plotFormantAlgorithm$, .sp$] / estimate_Vocal_Tract_Length.phi
	
	# Get all vowels around the "schwa" (hence cutoff = -24 semitones)
	@get_closest_vowels: -24, .sp$, .formants, .formants, .syllableKernels, .phi, 3*.phi, .vtlScaling
	for .f to 5
		.medianF'.f' = get_closest_vowels.medianF'.f'
		.spreadF'.f' = get_closest_vowels.spreadF'.f'
	endfor
		
	# Clean up
	selectObject: .pitch, .syllableKernels
	if .removeFormants <= 0
		plusObject: .formants
	endif
	Remove
endproc


# Convert the frequencies to coordinates
procedure vowel2point .scaling .targetFormantAlgorithm$ .sp$ .f1 .f2
	.scaleSt = 12*log2(.scaling)

	.spt1 = 12*log2(.f1)
	.spt2 = 12*log2(.f2)
	
	# Apply correction
	.spt1 += .scaleSt
	.spt2 += .scaleSt
	
	.a_St1 = 12*log2(phonemes [.targetFormantAlgorithm$, .sp$, "a_corner", "F1"])
	.a_St2 = 12*log2(phonemes [.targetFormantAlgorithm$, .sp$, "a_corner", "F2"])

	.i_St1 = 12*log2(phonemes [.targetFormantAlgorithm$, .sp$, "i_corner", "F1"])
	.i_St2 = 12*log2(phonemes [.targetFormantAlgorithm$, .sp$, "i_corner", "F2"])

	.u_St1 = 12*log2(phonemes [.targetFormantAlgorithm$, .sp$, "u_corner", "F1"])
	.u_St2 = 12*log2(phonemes [.targetFormantAlgorithm$, .sp$, "u_corner", "F2"])
	
	.dist_iu = sqrt((.i_St1 - .u_St1)^2 + (.i_St2 - .u_St2)^2)
	.theta = arcsin((.u_St1 - .i_St1)/.dist_iu)

	# First, with i_corner as (0, 0)
	.xp = ((.i_St2 - .spt2)/(.i_St2 - .u_St2))
	.yp = (.spt1 - min(.u_St1, .i_St1))/(.a_St1 - min(.u_St1, .i_St1))
	
	# Rotate around i_corner to make i-u axis horizontal
	.x = .xp * cos(.theta) + .yp * sin(.theta)
	.y = -1 * .xp * sin(.theta) + .yp * cos(.theta)
	
	# Reflect y-axis and make i_corner as (0, 1)
	.y = 1 - .y
	.yp = 1 - .yp
endproc



# Get a list of best targets with distances, one for each vowel segment found
# Use DTW to get the best match
procedure get_closest_vowels .cutoff .sp$ .formants .formantsPlot .textgrid .f1_o .f2_o .scaling
	.f1 = 0
	.f2 = 0
	
	# Convert to coordinates
	@vowel2point: 1, targetFormantAlgorithm$, .sp$, .f1_o, .f2_o
	.st_o1 = vowel2point.x
	.st_o2 = vowel2point.y
	
	# Get center coordinates
	.fc1 = phonemes [targetFormantAlgorithm$, .sp$, "@_center", "F1"]
	.fc2 = phonemes [targetFormantAlgorithm$, .sp$, "@_center", "F2"]
	@vowel2point: 1, targetFormantAlgorithm$, .sp$, .fc1, .fc2
	.st_c1 = vowel2point.x
	.st_c2 = vowel2point.y
	.tcDist_sqr = (.st_o1 - .st_c1)^2 + (.st_o2 - .st_c2)^2

	.vowelTier = 1
	.vowelNum = 0
	selectObject: .textgrid
	.numIntervals = Get number of intervals: .vowelTier
	.tableDistances = -1
	for .i to .numIntervals
		selectObject: .textgrid
		.label$ = Get label of interval: .vowelTier, .i
		if .label$ = "Vowel"
			.numDistance = 100000000000
			.numF1 = -1
			.numF2 = -1
			.num_t = 0
			selectObject: .textgrid
			.start = Get start time of interval: .vowelTier, .i
			.end = Get end time of interval: .vowelTier, .i
			selectObject: .formants
			.t = .start
			while .t <= .end
				.ftmp1 = Get value at time: 1, .t, "Hertz", "Linear"
				.ftmp2 = Get value at time: 2, .t, "Hertz", "Linear"
				@vowel2point: .scaling, targetFormantAlgorithm$, .sp$, .ftmp1, .ftmp2
				.stmp1 = vowel2point.x
				.stmp2 = vowel2point.y
				.tmpdistsqr = (.st_o1 - .stmp1)^2 + (.st_o2 - .stmp2)^2
				# Local
				if .tmpdistsqr < .numDistance
					.numDistance = .tmpdistsqr
					.numF1 = .ftmp1
					.numF2 = .ftmp2
					.numF3 = Get value at time: 3, .num_t, "Hertz", "Linear"
					.numF4 = Get value at time: 4, .num_t, "Hertz", "Linear"
					.numF5 = Get value at time: 5, .num_t, "Hertz", "Linear"
					.num_t = .t
				endif
				.t += 0.005
			endwhile
			
			# Convert to "real" (Burg) formant values
			if .formants != .formantsPlot
				selectObject: .formantsPlot
				.numF1 = Get value at time: 1, .num_t, "Hertz", "Linear"
				.numF2 = Get value at time: 2, .num_t, "Hertz", "Linear"
				.numF3 = Get value at time: 3, .num_t, "Hertz", "Linear"
				.numF4 = Get value at time: 4, .num_t, "Hertz", "Linear"
				.numF5 = Get value at time: 5, .num_t, "Hertz", "Linear"
			endif
			
			# Calculate the distance along the line between the 
			# center (c) and the target (t) from the best match 'v'
			# to the center.
			# 
			@vowel2point: .scaling, plotFormantAlgorithm$, .sp$, .numF1, .numF2
			.st1 = vowel2point.x
			.st2 = vowel2point.y
			
			.vcDist_sqr = (.st_c1 - .st1)^2 + (.st_c2 - .st2)^2
			.vtDist_sqr = (.st_o1 - .st1)^2 + (.st_o2 - .st2)^2
			.cvDist = (.tcDist_sqr + .vcDist_sqr - .vtDist_sqr)/(2*sqrt(.tcDist_sqr))
			
			# Only use positive distances
			if .cvDist = undefined or .cvDist >= .cutoff
				.vowelNum += 1
				.distance_list [.vowelNum] = sqrt(.numDistance)
				.f1_list [.vowelNum] = .numF1
				.f2_list [.vowelNum] = .numF2
				.f3_list [.vowelNum] = .numF3
				.f4_list [.vowelNum] = .numF4
				.f5_list [.vowelNum] = .numF5
				.t_list [.vowelNum] = .num_t
	
				# Only use frames where all formants are defined.
				.undefinedFormant = 0
				for .f to 5
					if .numF'.f' = undefined
						.undefinedFormant += 1
					endif
				endfor
				if .undefinedFormant <= 0
					if .tableDistances <= 0
						.tableDistances = Create Table with column names: "Distances", 1, "Distance F1 F2 F3 F4 F5"
					else
						selectObject: .tableDistances
						Insert row: 1
					endif
					selectObject: .tableDistances
					Set numeric value: 1, "Distance", .cvDist
					Set numeric value: 1, "F1", .numF1
					Set numeric value: 1, "F2", .numF2
					Set numeric value: 1, "F3", .numF3
					Set numeric value: 1, "F4", .numF4
					Set numeric value: 1, "F5", .numF5
				endif
				
			endif
		endif
	endfor
	.meanDistance = -1
	.stdevDistance = -1
	if .tableDistances > 0
		selectObject: .tableDistances
		.meanDistance = Get mean: "Distance"
		.stdevDistance = Get standard deviation: "Distance"
		if .stdevDistance = undefined
			.stdevDistance = .meanDistance/2
		endif
		
		for .f to 5
			selectObject: .tableDistances
			.medianF'.f' = Get quantile: "F'.f'", 0.50
			.quant90F'.f' = Get quantile: "F'.f'", 0.90
			.quant10F'.f' = Get quantile: "F'.f'", 0.10
			.spreadF'.f' = .quant90F'.f' - .quant10F'.f'
		endfor
		
		
		Remove
	endif
endproc

procedure select_vowel_target .sp$ .sound .formants .formantsBandwidth .textgrid
	.f1_Lowest = phonemes [targetFormantAlgorithm$, .sp$, "i_corner", "F1"]
	.f1_Highest = (1050/900) * phonemes [targetFormantAlgorithm$, .sp$, "a_corner", "F1"]
	selectObject: .textgrid
	.duration = Get total duration
	.firstTier$ = Get tier name: 1
	if .firstTier$ <> "Vowel"
		Insert point tier: 1, "VowelTarget"
		Insert interval tier: 1, "Vowel"
	endif
	.vowelTier = 1
	.targetTier = 2
	.peakTier = 3
	.valleyTier = 4
	.silencesTier = 5
	.vuvTier = 6

	selectObject: .sound
	.samplingFrequency = Get sampling frequency
	.intensity = Get intensity (dB)
	selectObject: .formantsBandwidth
	.totalNumFrames = Get number of frames
		
	# Nothing found, but there is sound. Try to find at least 1 vowel
	
	selectObject: .textgrid
	.numPeaks = Get number of points: .peakTier	
	if .numPeaks <= 0 and .intensity >= 45
		selectObject: .sound
		.t_max = Get time of maximum: 0, 0, "Sinc70"
		.pp = noprogress To PointProcess (periodic, cc): 75, 600
		.textGrid = noprogress To TextGrid (vuv): 0.02, 0.01
		.i = Get interval at time: 1, .t_max
		.label$ = Get label of interval: 1, .i
		.start = Get start time of interval: 1, .i
		.end = Get end time of interval: 1, .i
		if .label$ = "V"
			selectObject: .syllableKernels
			Insert point: .peakTier, .t_max, "P"
			Insert point: .valleyTier, .start, "V"
			Insert point: .valley, .end, "V"
		endif
	endif
	
	selectObject: .sound
	.voicePP = noprogress To PointProcess (periodic, cc): 75, 600
	selectObject: .textgrid
	.numPeaks = Get number of points: .peakTier
	.numValleys = Get number of points: .valleyTier
	for .p to .numPeaks
		selectObject: .textgrid
		.tp = Get time of point: .peakTier, .p
		# Find boundaries
		# From valleys
		.tl = 0
		.vl = Get low index from time: .valleyTier, .tp
		if .vl > 0 and .vl < .numValleys
			.tl = Get time of point: .valleyTier, .vl
		endif
		.th = .duration
		.vh = Get high index from time: .valleyTier, .tp
		if .vh > 0 and .vh < .numValleys
			.th = Get time of point: .valleyTier, .vh
		endif
		# From silences
		.sl = Get interval at time: .silencesTier, .tl
		.label$ = Get label of interval: .silencesTier, .sl
		.tsl = .tl
		if .label$ = "silent"
			.tsl = Get end time of interval: .silencesTier, .sl
		endif
		if .tsl > .tl and .tsl < .tp
			.tl = .tsl
		endif
		.sh = Get interval at time: .silencesTier, .th
		.label$ = Get label of interval: .silencesTier, .sh
		.tsh = .th
		if .label$ = "silent"
			.tsh = Get start time of interval: .silencesTier, .sh
		endif
		if .tsh < .th and .tsh > .tp
			.th = .tsh
		endif
		
		# From vuv
		.vuvl = Get interval at time: .vuvTier, .tl
		.label$ = Get label of interval: .vuvTier, .vuvl
		.tvuvl = .tl
		if .label$ = "U"
			.tvuvl = Get end time of interval: .vuvTier, .vuvl
		endif
		if .tvuvl > .tl and .tvuvl < .tp
			.tl = .tvuvl
		endif
		.vuvh = Get interval at time: .vuvTier, .th
		.label$ = Get label of interval: .vuvTier, .vuvh
		.tvuvh = .th
		if .label$ = "U"
			.tvuvh = Get start time of interval: .vuvTier, .vuvh
		endif
		if .tvuvh < .th and .tvuvh > .tp
			.th = .tvuvh
		endif
		
		# From formants: 300 <= F1 <= 1000
		# F1 >= 300
		selectObject: .formants
		.dt = Get time step

		selectObject: .formants
		.f = Get value at time: 1, .tl, "Hertz", "Linear"
		selectObject: .formantsBandwidth
		.b = Get bandwidth at time: 1, .tl, "Hertz", "Linear"
		.iframe = Get frame number from time: .tl
		.iframe = round(.iframe)
		if .iframe > .totalNumFrames
			.iframe = .totalNumFrames
		elsif .iframe < 1
			.iframe = 1
		endif
		.nf = Get number of formants: .iframe
		while (.f < .f1_Lowest or .f > .f1_Highest or .b > 0.7 * .f or .nf < 4) and .tl + .dt < .th
			.tl += .dt
			selectObject: .formants
			.f = Get value at time: 1, .tl, "Hertz", "Linear"
			selectObject: .formantsBandwidth
			.b = Get bandwidth at time: 1, .tl, "Hertz", "Linear"
			.iframe = Get frame number from time: .tl
			.iframe = round(.iframe)
			if .iframe > .totalNumFrames
				.iframe = .totalNumFrames
			elsif .iframe < 1
				.iframe = 1
			endif
			.nf = Get number of formants: .iframe		
		endwhile

		selectObject: .formants
		.f = Get value at time: 1, .th, "Hertz", "Linear"
		selectObject: .formantsBandwidth
		.b = Get bandwidth at time: 1, .th, "Hertz", "Linear"
		.iframe = Get frame number from time: .th
		.iframe = round(.iframe)
		if .iframe > .totalNumFrames
			.iframe = .totalNumFrames
		elsif .iframe < 1
			.iframe = 1
		endif
		.nf = Get number of formants: .iframe
		while (.f < .f1_Lowest or .f > .f1_Highest or .b > 0.7 * .f or .nf < 4) and .th - .dt > .tl
			.th -= .dt
			selectObject: .formants
			.f = Get value at time: 1, .th, "Hertz", "Linear"
			selectObject: .formantsBandwidth
			.b = Get bandwidth at time: 1, .th, "Hertz", "Linear"
			.iframe = Get frame number from time: .th
			.iframe = round(.iframe)
		    .iframe = round(.iframe)
			if .iframe > .totalNumFrames
				.iframe = .totalNumFrames
			elsif .iframe < 1
				.iframe = 1
			endif
			.nf = Get number of formants: .iframe		
		endwhile
		
		# New points
		if .th - .tl > 0.01
			selectObject: .textgrid
			.numPoints = Get number of points: .targetTier
			
			selectObject: .formants
			if .tp > .tl and .tp < .th
				.tt = .tp
			else
				.tt = (.tl+.th)/2
				.f1_median = Get quantile: 1, .tl, .th, "Hertz", 0.5 
				.f2_median = Get quantile: 2, .tl, .th, "Hertz", 0.5 
				if .f1_median > 400
					.tt = Get time of maximum: 1, .tl, .th, "Hertz", "Parabolic"
				elsif .f2_median > 1600
					.tt = Get time of maximum: 2, .tl, .th, "Hertz", "Parabolic"
				elsif .f2_median < 1100
					.tt = Get time of minimum: 2, .tl, .th, "Hertz", "Parabolic"
				endif
				
				if .tt < .tl + 0.01 or .tt > .th - 0.01
					.tt = (.tl+.th)/2
				endif
			endif
			
			# Insert Target
			selectObject: .textgrid
			.numPoints = Get number of points: .targetTier
			.tmp = 0
			if .numPoints > 0
				.tmp = Get time of point: .targetTier, .numPoints
			endif
			if .tt <> .tmp
				Insert point: .targetTier, .tt, "T"
			endif
			
			# Now find vowel interval from taget
			.ttl = .tt
			# Lower end
			selectObject: .formants
			.f = Get value at time: 1, .ttl, "Hertz", "Linear"
			selectObject: .formantsBandwidth
			.b = Get bandwidth at time: 1, .ttl, "Hertz", "Linear"
			.iframe = Get frame number from time: .th
			.iframe = round(.iframe)
			if .iframe > .totalNumFrames
				.iframe = .totalNumFrames
			elsif .iframe < 1
				.iframe = 1
			endif
			.nf = Get number of formants: .iframe	
			
			# Voicing: Is there a voiced point below within 0.02 s?
			selectObject: .voicePP
			.i_near = Get nearest index: .ttl - .dt
			.pp_near = Get time from index: .i_near
			
			while (.f > .f1_Lowest and .f < .f1_Highest and .b < 0.9 * .f and .nf >= 4) and .ttl - .dt >= .tl and abs((.ttl - .dt) - .pp_near) <= 0.02
				.ttl -= .dt
				selectObject: .formants
				.f = Get value at time: 1, .ttl, "Hertz", "Linear"
				selectObject: .formantsBandwidth
				.b = Get bandwidth at time: 1, .ttl, "Hertz", "Linear"
				.iframe = Get frame number from time: .ttl
				.iframe = round(.iframe)
				if .iframe > .totalNumFrames
					.iframe = .totalNumFrames
				elsif .iframe < 1
					.iframe = 1
				endif
				.nf = Get number of formants: .iframe
				# Voicing: Is there a voiced point below within 0.02 s?
				selectObject: .voicePP
				.i_near = Get nearest index: .ttl - .dt
				.pp_near = Get time from index: .i_near
			endwhile
			# Make sure something has changed
			if .ttl > .tt - 0.01
				.ttl = .tl
			endif
			
			# Higher end
			.tth = .tp
			selectObject: .formants
			.f = Get value at time: 1, .tth, "Hertz", "Linear"
			selectObject: .formantsBandwidth
			.b = Get bandwidth at time: 1, .tth, "Hertz", "Linear"
			.iframe = Get frame number from time: .th
			.iframe = round(.iframe)
			if .iframe > .totalNumFrames
				.iframe = .totalNumFrames
			elsif .iframe < 1
				.iframe = 1
			endif
			.nf = Get number of formants: .iframe		
			
			# Voicing: Is there a voiced point above within 0.02 s?
			selectObject: .voicePP
			.i_near = Get nearest index: .ttl + .dt
			.pp_near = Get time from index: .i_near
			
			while (.f > .f1_Lowest and .f < .f1_Highest and .b < 0.9 * .f and .nf >= 4) and .tth + .dt <= .th and abs((.ttl + .dt) - .pp_near) <= 0.02
				.tth += .dt
				selectObject: .formants
				.f = Get value at time: 1, .tth, "Hertz", "Linear"
				selectObject: .formantsBandwidth
				.b = Get bandwidth at time: 1, .tth, "Hertz", "Linear"
				.iframe = Get frame number from time: .tth
				.iframe = round(.iframe)
				if .iframe > .totalNumFrames
					.iframe = .totalNumFrames
				elsif .iframe < 1
					.iframe = 1
				endif
				.nf = Get number of formants: .iframe		
				# Voicing: Is there a voiced point above within 0.02 s?
				selectObject: .voicePP
				.i_near = Get nearest index: .ttl + .dt
				.pp_near = Get time from index: .i_near
			endwhile
			# Make sure something has changed
			if .tth < .tt + 0.01
				.tth = .th
			endif
			
			# Insert interval
			selectObject: .textgrid
			.index = Get interval at time: .vowelTier, .ttl
			.start = Get start time of interval: .vowelTier, .index
			.end = Get end time of interval: .vowelTier, .index
			if .ttl <> .start and .ttl <> .end
				Insert boundary: .vowelTier, .ttl
			endif
			.index = Get interval at time: .vowelTier, .tth
			.start = Get start time of interval: .vowelTier, .index
			.end = Get end time of interval: .vowelTier, .index
			if .tth <> .start and .tth <> .end
				Insert boundary: .vowelTier, .tth
			endif
			.index = Get interval at time: .vowelTier, .tt
			.start = Get start time of interval: .vowelTier, .index
			.end = Get end time of interval: .vowelTier, .index
			# Last sanity checks on voicing and intensity
			# A vowel is voiced
			selectObject: .voicePP
			.meanPeriod = Get mean period: .start, .end, 0.0001, 0.02, 1.3
			if .meanPeriod <> undefined
				selectObject: .sound
				.sd = Get standard deviation: 1, .start, .end
				# Is there enough sound to warrant a vowel? > -15dB
				if 20*log10(.sd/(2*10^-5)) - .intensity > -15
					selectObject: .textgrid
					Set interval text: .vowelTier, .index, "Vowel"
				endif
			endif
		endif
	endfor
	
	selectObject: .voicePP
	Remove
	
endproc

###########################################################################
# 
# Replace a spectral band [.low, .high] in the source by the replacement
#

procedure replaceBand .source .replacement .low .high

	# Remove .low - .high band from source
	selectObject: .source
	if .low <= 0
		# High pass
		.filteredSource = Filter (pass Hann band): .high, 20000, .high / 10
	elsif .high <= 0 or .high >= 20000
		# Low pass
		.filteredSource = Filter (pass Hann band): 0, .low, .low / 10
	else
		# Stop band
		.filteredSource = Filter (stop Hann band): .low, .high, .low / 10
	endif
	
	# Extract band from replacement
	selectObject: .replacement
	if .low <= 0
		# Low pass
		.filteredReplacement = Filter (pass Hann band): 0, .high, .high / 10
	elsif .high <= 0 or .high >= 20000
		# High pass
		.filteredReplacement = Filter (pass Hann band): .low, 20000, .low / 10
	else
		# Pass band
		.filteredReplacement = Filter (pass Hann band): .low, .high, .low / 10
	endif

	# Combine bands into stereo
	selectObject: .filteredSource, .filteredReplacement
	.tmp = Combine to stereo
	.target = Convert to mono

	selectObject: .filteredSource, .filteredReplacement, .tmp
	Remove
endproc


###########################################################################
#                                                                         #
#  Praat Script Syllable Nuclei                                           #
#  Copyright (C) 2017  R.J.J.H. van Son                                   #
#                                                                         #
#    This program is free software: you can redistribute it and/or modify #
#    it under the terms of the GNU General Public License as published by #
#    the Free Software Foundation, either version 2 of the License, or    #
#    (at your option) any later version.                                  #
#                                                                         #
#    This program is distributed in the hope that it will be useful,      #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of       #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        #
#    GNU General Public License for more details.                         #
#                                                                         #
#    You should have received a copy of the GNU General Public License    #
#    along with this program.  If not, see http://www.gnu.org/licenses/   #
#                                                                         #
###########################################################################
#                                                                         #
# Simplified summary of the script by Nivja de Jong and Ton Wempe         #
#                                                                         #
# Praat script to detect syllable nuclei and measure speech rate          # 
# automatically                                                           #
# de Jong, N.H. & Wempe, T. Behavior Research Methods (2009) 41: 385.     #
# https://doi.org/10.3758/BRM.41.2.385                                    #
# 
procedure segment_syllables .silence_threshold .minimum_dip_between_peaks .minimum_pause_duration .keep_Soundfiles_and_Textgrids .soundid
	# Get intensity
	selectObject: .soundid
	.intensity = noprogress To Intensity: 70, 0, "yes"
	.dt = Get time step
	.maxFrame = Get number of frames
	
	# Determine Peaks
	selectObject: .intensity
	.peaksInt = noprogress To IntensityTier (peaks)
	.peaksPoint = Down to PointProcess
	.peaksPointTier = Up to TextTier: "P"
	Rename: "Peaks"
	
	# Determine valleys
	selectObject: .intensity
	.valleyInt = noprogress To IntensityTier (valleys)
	.valleyPoint = Down to PointProcess
	.valleyPointTier = Up to TextTier: "V"
	Rename: "Valleys"
	
	selectObject: .peaksPointTier, .valleyPointTier
	.segmentTextGrid = Into TextGrid
	
	selectObject: .peaksPointTier, .valleyPointTier, .peaksInt, .peaksPoint, .valleyInt, .valleyPoint
	Remove
	
	# Select the sounding part
	selectObject: .intensity
	.silenceTextGrid = noprogress To TextGrid (silences): .silence_threshold, .minimum_pause_duration, 0.05, "silent", "sounding"
	
	# Determine voiced parts
	selectObject: .soundid
	.voicePP = noprogress To PointProcess (periodic, cc): 75, 600
	.vuvTextGrid = noprogress To TextGrid (vuv): 0.02, 0.01
	plusObject: .segmentTextGrid, .silenceTextGrid
	.textgridid = Merge
	
	selectObject: .vuvTextGrid, .silenceTextGrid, .segmentTextGrid, .voicePP
	Remove
	
	# Remove irrelevant peaks and valleys
	selectObject: .textgridid
	.numPeaks = Get number of points: 1
	for .i to .numPeaks
		.t = Get time of point: 1, .numPeaks + 1 - .i
		.s = Get interval at time: 3, .t
		.soundLabel$ = Get label of interval: 3, .s
		.v = Get interval at time: 4, .t
		.voiceLabel$ = Get label of interval: 4, .v
		if .soundLabel$ = "silent" or .voiceLabel$ = "U"
			Remove point: 1, .numPeaks + 1 - .i
		endif
	endfor
	
	# valleys
	selectObject: .textgridid
	.numValleys = Get number of points: 2
	.numPeaks = Get number of points: 1
	# No peaks, nothing to do
	if .numPeaks <= 0
		goto VALLEYREADY
	endif
	
	for .i from 2 to .numValleys
		selectObject: .textgridid
		.il = .numValleys + 1 - .i
		.ih = .numValleys + 2 - .i
		.tl = Get time of point: 2, .il
		.th = Get time of point: 2, .ih
		
		
		.ph = Get high index from time: 1, .tl
		.tph = 0
		if .ph > 0 and .ph <= .numPeaks
			.tph = Get time of point: 1, .ph
		endif
		# If there is no peak between the valleys remove the highest
		if .tph <= 0 or (.tph < .tl or .tph > .th)
			# If the area is silent for both valleys, keep the one closest to a peak
			.psl = Get interval at time: 3, .tl
			.psh = Get interval at time: 3, .th
			.psl_label$ = Get label of interval: 3, .psl
			.psh_label$ = Get label of interval: 3, .psh
			if .psl_label$ = "silent" and .psh_label$ = "silent"
				.plclosest = Get nearest index from time: 1, .tl
				if .plclosest <= 0
					.plclosest = 1
				endif
				if .plclosest > .numPeaks
					.plclosest = .numPeaks
				endif
				.tlclosest = Get time of point: 1, .plclosest
				.phclosest = Get nearest index from time: 1, .th
				if .phclosest <= 0
					.phclosest = 1
				endif
				if .phclosest > .numPeaks
					.phclosest = .numPeaks
				endif
				.thclosest = Get time of point: 1, .phclosest
				if abs(.tlclosest - .tl) > abs(.thclosest - .th)
					selectObject: .textgridid
					Remove point: 2, .il
				else
					selectObject: .textgridid
					Remove point: 2, .ih
				endif
			else
				# Else Compare valley depths
				selectObject: .intensity
				.intlow = Get value at time: .tl, "Cubic"
				.inthigh = Get value at time: .th, "Cubic"
				if .inthigh >= .intlow
					selectObject: .textgridid
					Remove point: 2, .ih
				else
					selectObject: .textgridid
					Remove point: 2, .il
				endif
			endif
		endif
	endfor

	# Remove superfluous valleys
	selectObject: .textgridid
	.numValleys = Get number of points: 2
	.numPeaks = Get number of points: 1
	for .i from 1 to .numValleys
		selectObject: .textgridid
		.iv = .numValleys + 1 - .i
		.tv = Get time of point: 2, .iv
		.ph = Get high index from time: 1, .tv
		if .ph > .numPeaks
			.ph = .numPeaks
		endif
		.tph = Get time of point: 1, .ph
		.pl = Get low index from time: 1, .tv
		if .pl <= 0
			.pl = 1
		endif
		.tpl = Get time of point: 1, .pl
		
		# Get intensities
		selectObject: .intensity
		.v_int = Get value at time: .tv, "Cubic"
		.pl_int = Get value at time: .tpl, "Cubic"
		.ph_int = Get value at time: .tph, "Cubic"
		# If there is no real dip, remove valey and lowest peak
		if min((.pl_int - .v_int), (.ph_int - .v_int)) < .minimum_dip_between_peaks
			selectObject: .textgridid
			Remove point: 2, .iv
			if .ph <> .pl
				if .pl_int < .ph_int
					Remove point: 1, .pl
				else
					Remove point: 1, .ph
				endif
			endif
			.numPeaks = Get number of points: 1
			if .numPeaks <= 0
				goto VALLEYREADY
			endif
		endif
	endfor
	label VALLEYREADY
	
	selectObject: .intensity
	Remove
	
	# Determine syllable rate
	selectObject: .textgridid
	.duration = Get total duration
	.numPeaks = Get number of points: 1
	.speakingrate = .numPeaks / .duration
	.numInt = Get number of intervals: 3
	.durSounding = 0
	.durSilent = 0
	.numPauses = 0
	for .i to .numInt
		.start = Get start time of interval: 3, .i
		.end = Get end time of interval: 3, .i
		.d = .end - .start
		.label$ = Get label of interval: 3, .i
		if .label$ = "sounding"
			.durSounding += .d
		else
			.durSilent += .d
			.numPauses += 1
		endif
	endfor
	.articulationrate = .numPeaks / .durSounding
	.asd = .durSilent / .numPauses
	
	selectObject: .textgridid
endproc

#
# Vocal Tract Length according to:
# Lammert, Adam C., and Shrikanth S. Narayanan. 
# “On Short-Time Estimation of Vocal Tract Length from Formant Frequencies.” 
# Edited by Charles R Larson. PLOS ONE 10, no. 7 (July 15, 2015): e0132193. 
# https://doi.org/10.1371/journal.pone.0132193.
#
procedure estimate_Vocal_Tract_Length .formants .syllableKernels .targetTier
	# Coefficients
	.beta[0] = 229
	.beta[1] = 0.030
	.beta[2] = 0.082
	.beta[3] = 0.124
	.beta[4] = 0.354
	
	.sp$ = "F"
	.phi = 500
	.vtl = -1
	
	.numTargets = -1
	for .iteration to 6
		@get_closest_vowels: 0, .sp$, .formants, .formants, .syllableKernels, .phi, 3*.phi, 1
		
		.numTargets = get_closest_vowels.vowelNum
		.n = 0
		.sumVTL = 0
		for .p to .numTargets
			.currentPhi = .beta[0]
			for .i to 4
				.f[.i] =  get_closest_vowels.f'.i'_list [.p]
				if .f[.i] <> undefined and .currentPhi <> undefined
					.currentPhi += .beta[.i] * .f[.i] / (2*.i - 1)
				else
					.currentPhi = undefined
				endif
			endfor
			if .currentPhi <> undefined
				.currentVTL = 100 * 352.95 / (4*.currentPhi)
				.sumVTL += .currentVTL
				.n += 1
			endif
		endfor
		
		if .n > 0
			.vtl = .sumVTL / .n
			# L = c / (4*Phi) (cm)
			.phi = 100 * 352.95 / (4*.vtl)
			
			.sp$ = "F"
			if .phi < averagePhi_VTL [plotFormantAlgorithm$, "A"]
				.sp$ = "M"
			endif
		endif
	endfor
endproc


procedure determineFormantValues .formants .textGrid .targetTier
	
	.formantTable = Create Table with column names: "FormantTable", 1, "T F1 F2 F3 F4 F5"

	selectObject: .textGrid
	.numTargets = Get number of points: .targetTier
	.n = 0
	.sumVTL = 0
	for .p to .numTargets
		selectObject: .textGrid
		.t = Get time of point: .targetTier, .p
		selectObject: .formantTable
		.row = Get number of rows
		selectObject: .formants
		.value1 = Get value at time: 1, .t, "Hertz", "Linear"
		.value2 = Get value at time: 2, .t, "Hertz", "Linear"
		if .value1  > 0 and .value2 > 0
			for .f to 5
				selectObject: .formants
				.value = Get value at time: .f, .t, "Hertz", "Linear"
				if .value = undefined
					.value = 0
				endif
				selectObject: .formantTable
				Set numeric value: .row, "T", .t
				Set numeric value: .row, "F'.f'", .value
			endfor
			selectObject: .formantTable
			Append row
		endif
	endfor
	# Remove empty last row
	selectObject: .formantTable
	.row = Get number of rows
	Remove row: .row
	
	# Values
	selectObject: .formantTable
	for .f to 5
		.medianF'.f' = Get quantile: "F'.f'", 0.50
		.quant90F'.f' = Get quantile: "F'.f'", 0.90
		.quant10F'.f' = Get quantile: "F'.f'", 0.10
		.spreadF'.f' = .quant90F'.f' - .quant10F'.f'
	endfor
	
endproc

####################################################################

procedure IntitalizeFormantSpace

# Vowel targets
targetFormantAlgorithm$ = "Robust"

# Plotting can be different from the target, in principle
plotFormantAlgorithm$ = targetFormantAlgorithm$

numVowels = 12
vowelList$ [1] = "i"
vowelList$ [2] = "I"
vowelList$ [3] = "e"
vowelList$ [4] = "E"
vowelList$ [5] = "a"
vowelList$ [6] = "A"
vowelList$ [7] = "O"
vowelList$ [8] = "o"
vowelList$ [9] = "u"
vowelList$ [10] = "y"
vowelList$ [11] = "Y"
vowelList$ [12] = "@"

color$ ["a"] = "Red"
color$ ["i"] = "Green"
color$ ["u"] = "Blue"
color$ ["@"] = "{0.8,0.8,0.8}"

# Formant values according to 
# IFA corpus averages from FPA isolated vowels


###############################################
#
# Robust formant algorithm (Robust)
#
###############################################

# Male
phonemes ["Robust", "M", "A", "F1"] = 680
phonemes ["Robust", "M", "A", "F2"] = 1038
phonemes ["Robust", "M", "E", "F1"] = 510
phonemes ["Robust", "M", "E", "F2"] = 1900
phonemes ["Robust", "M", "I", "F1"] = 354
phonemes ["Robust", "M", "I", "F2"] = 2167
phonemes ["Robust", "M", "O", "F1"] = 446
phonemes ["Robust", "M", "O", "F2"] = 680
phonemes ["Robust", "M", "Y", "F1"] = 389
phonemes ["Robust", "M", "Y", "F2"] = 1483
phonemes ["Robust", "M", "Y:", "F1"] = 370
phonemes ["Robust", "M", "Y:", "F2"] = 1508
phonemes ["Robust", "M", "a", "F1"] = 797
phonemes ["Robust", "M", "a", "F2"] = 1328
phonemes ["Robust", "M", "au", "F1"] = 542
phonemes ["Robust", "M", "au", "F2"] = 945
phonemes ["Robust", "M", "e", "F1"] = 351
phonemes ["Robust", "M", "e", "F2"] = 2180
phonemes ["Robust", "M", "ei", "F1"] = 471
phonemes ["Robust", "M", "ei", "F2"] = 1994
phonemes ["Robust", "M", "i", "F1"] = 242
phonemes ["Robust", "M", "i", "F2"] = 2330
phonemes ["Robust", "M", "o", "F1"] = 393
phonemes ["Robust", "M", "o", "F2"] = 692
phonemes ["Robust", "M", "u", "F1"] = 269
phonemes ["Robust", "M", "u", "F2"] = 626
phonemes ["Robust", "M", "ui", "F1"] = 475
phonemes ["Robust", "M", "ui", "F2"] = 1523
phonemes ["Robust", "M", "y", "F1"] = 254
phonemes ["Robust", "M", "y", "F2"] = 1609

# Guessed
phonemes ["Robust", "M", "@", "F1"] = 373
phonemes ["Robust", "M", "@", "F2"] = 1247

# Female
phonemes ["Robust", "F", "A", "F1"] = 826
phonemes ["Robust", "F", "A", "F2"] = 1208
phonemes ["Robust", "F", "E", "F1"] = 648
phonemes ["Robust", "F", "E", "F2"] = 2136
phonemes ["Robust", "F", "I", "F1"] = 411
phonemes ["Robust", "F", "I", "F2"] = 2432
phonemes ["Robust", "F", "O", "F1"] = 527
phonemes ["Robust", "F", "O", "F2"] = 836
phonemes ["Robust", "F", "Y", "F1"] = 447
phonemes ["Robust", "F", "Y", "F2"] = 1698
phonemes ["Robust", "F", "Y:", "F1"] = 404
phonemes ["Robust", "F", "Y:", "F2"] = 1750
phonemes ["Robust", "F", "a", "F1"] = 942
phonemes ["Robust", "F", "a", "F2"] = 1550
phonemes ["Robust", "F", "au", "F1"] = 600
phonemes ["Robust", "F", "au", "F2"] = 1048
phonemes ["Robust", "F", "e", "F1"] = 409
phonemes ["Robust", "F", "e", "F2"] = 2444
phonemes ["Robust", "F", "ei", "F1"] = 618
phonemes ["Robust", "F", "ei", "F2"] = 2196
phonemes ["Robust", "F", "i", "F1"] = 271
phonemes ["Robust", "F", "i", "F2"] = 2667
phonemes ["Robust", "F", "o", "F1"] = 470
phonemes ["Robust", "F", "o", "F2"] = 879
phonemes ["Robust", "F", "u", "F1"] = 334
phonemes ["Robust", "F", "u", "F2"] = 686
phonemes ["Robust", "F", "ui", "F1"] = 594
phonemes ["Robust", "F", "ui", "F2"] = 1669
phonemes ["Robust", "F", "y", "F1"] = 285
phonemes ["Robust", "F", "y", "F2"] = 1765

# Guessed
phonemes ["Robust", "F", "@", "F1"] = 440
phonemes ["Robust", "F", "@", "F2"] = 1415

# Triangle
# Male
phonemes ["Robust", "M", "i_corner", "F1"] = phonemes ["Robust", "M", "i", "F1"]/(2^(1/12))
phonemes ["Robust", "M", "i_corner", "F2"] = phonemes ["Robust", "M", "i", "F2"]*(2^(1/12))
phonemes ["Robust", "M", "a_corner", "F1"] = phonemes ["Robust", "M", "a", "F1"]*(2^(1/12))
phonemes ["Robust", "M", "a_corner", "F2"] = phonemes ["Robust", "M", "a", "F2"]
phonemes ["Robust", "M", "u_corner", "F1"] = phonemes ["Robust", "M", "u", "F1"]/(2^(1/12))
phonemes ["Robust", "M", "u_corner", "F2"] = phonemes ["Robust", "M", "u", "F2"]/(2^(1/12))
# @_center is not fixed but derived from current corners
phonemes ["Robust", "M", "@_center", "F1"] =(phonemes ["Robust", "M", "i_corner", "F1"]*phonemes ["Robust", "M", "u_corner", "F1"]*phonemes ["Robust", "M", "a_corner", "F1"])^(1/3)
phonemes ["Robust", "M", "@_center", "F2"] = (phonemes ["Robust", "M", "i_corner", "F2"]*phonemes ["Robust", "M", "u_corner", "F2"]*phonemes ["Robust", "M", "a_corner", "F2"])^(1/3)
                                              
# Female
phonemes ["Robust", "F", "i_corner", "F1"] = phonemes ["Robust", "F", "i", "F1"]/(2^(1/12))
phonemes ["Robust", "F", "i_corner", "F2"] = phonemes ["Robust", "F", "i", "F2"]*(2^(1/12))
phonemes ["Robust", "F", "a_corner", "F1"] = phonemes ["Robust", "F", "a", "F1"]*(2^(1/12))
phonemes ["Robust", "F", "a_corner", "F2"] = phonemes ["Robust", "F", "a", "F2"]
phonemes ["Robust", "F", "u_corner", "F1"] = phonemes ["Robust", "F", "u", "F1"]/(2^(1/12))
phonemes ["Robust", "F", "u_corner", "F2"] = phonemes ["Robust", "F", "u", "F2"]/(2^(1/12))
# @_center is not fixed but derived from current corners
phonemes ["Robust", "F", "@_center", "F1"] =(phonemes ["Robust", "F", "i_corner", "F1"]*phonemes ["Robust", "F", "u_corner", "F1"]*phonemes ["Robust", "F", "a_corner", "F1"])^(1/3)
phonemes ["Robust", "F", "@_center", "F2"] = (phonemes ["Robust", "F", "i_corner", "F2"]*phonemes ["Robust", "F", "u_corner", "F2"]*phonemes ["Robust", "F", "a_corner", "F2"])^(1/3)

# Vocal Tract Length
# Sex  VTL   Phi
# F    15.24	579.27
# M    16.29	542.28
averagePhi_VTL ["Robust", "F"] = 579.27
averagePhi_VTL ["Robust", "M"] = 542.28
# Classification boundary
averagePhi_VTL ["Robust", "A"] = 540.51

endproc

###############################################################

