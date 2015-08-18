sub Main()
	app = CreateObject("roAppManager")
	theme = CreateObject("roAssociativeArray")

	theme.OverhangSliceSD = "pkg:/images/Overhang_BackgroundSlice_Blue_SD43.png"
	theme.OverhangSliceHD = "pkg:/images/Overhang_BackgroundSlice_Blue_HD.png"
	theme.OverhanglogoHD = "pkg:/images/Logo_Overhang_Roku_SDK_HD.png"
	theme.OverhanglogoSD = "pkg:/images/Logo_Overhang_Roku_SDK_SD43.png"
	theme.OverhangPrimaryLogoOffsetHD_X = "100"
	theme.OverhangPrimaryLogoOffsetHD_Y = "60"
	theme.OverhangPrimaryLogoOffsetSD_X = "60"
	theme.OverhangPrimaryLogoOffsetSD_Y = "40"

  app.SetTheme(theme)

  ' set up some content
  video = {
    title:        "TEDTalks : David Brooks: The social animal"
    sdPosterURL:  "http://images.ted.com/images/ted/78e8d94d1d2a81cd182e0626dc8e96a43c88d760_132x99.jpg"
    hdPosterURL:  "http://images.ted.com/images/ted/78e8d94d1d2a81cd182e0626dc8e96a43c88d760_132x99.jpg"
    description:  "Tapping into the findings of his latest book, NYTimes columnist David Brooks unpacks new insights into human nature from the cognitive sciences -- insights with massive implications for economics and politics as well as our own self-knowledge. In a talk full of humor, he shows how you can't hope to understand humans as separate individuals making choices based on their conscious awareness."
    contentType:  "episode"
    streamFormat: "mp4"
    stream: {
      url:  "http://video.ted.com/talks/podcast/DavidBrooks_2011.mp4"
    }
  }
  
  ' set up a pre-roll ad
  vast = NWM_VAST()
 	vastURL = "s3-us-west-1.amazonaws.com/rokutestchannel1/xml/vast.xml"
 	util = NWM_Utilities()
 	raw = util.GetStringFromURL(vastURL)
 	? raw
 	vast.Parse(raw, false, true)
 	if vast.video <> invalid 'vast.ads.Count() > 0 and vast.ads[0].video <> invalid
 	  PrintAA(vast.video)
    video.preroll = vast.video
    video.preroll.minBandwidth = 250
    video.preroll.switchingStrategy = "full-adaptation"
  end if
  
  ' GO!
	ShowSpringboardScreen([video], 0)
end sub
