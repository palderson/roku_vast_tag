'
' NWM_Vast.brs
' chagedorn@roku.com
'
' A BrightScript class for parsing VAST ad data
'
' USAGE
'   vast = NWM_VAST()
'   if vast.Parse(raw)
'     for each ad in vast.ads
'       ' do something useful with the ad
'     next
'   end if
'
' NOTES
'   TRACKING EVENTS RELY ON AN ACCURATE <duration> TAG FOR TIMING.
'   If a creative has an incorrect <duration> tag, the tracking
'   events for that creative will not fire at the correct times.
'
'   120430 initial version only supports mp4 video ads
'   120621 added support for VAST responses that contain multiple <ad> elements
'   130205 added support for video/x-mp4 and moved the list of supported mime types into the constructor
'   130810 added support for the "CREATIVEVIEW" tracking event
'          added optional URL normalization the the Parse() function
'

' constructor
function NWM_VAST()
  this = {
    debug: true
    ads: []
    supportedMimeTypes: {}
    
    Parse: NWM_VAST_Parse
    GetPrerollFromURL: NWM_VAST_GetPrerollFromURL
  }
  
  ' be sure to use all lowercase
  this.supportedMimeTypes.AddReplace("video/mp4", true)
  this.supportedMimeTypes.AddReplace("video/x-mp4", true)
  
  return this
end function

' Parse
' parse a chunk of VAST XML and construct an extended content-meta-data object
'
' raw
'   the VAST XML to be parsed
' returnUnsupportedVideo
'   By default, the result will exclude video whose mime-type is not in m.supportedMimeTypes
'          
function NWM_VAST_Parse(raw, returnUnsupportedVideo = false, normalizeURLs = false)
  result = false
  m.companionAds = invalid
  m.video = invalid
  m.ads = []
  
  xml = CreateObject("roXMLElement")
  if xml.Parse(raw)
    result = true
    
    xfer = CreateObject("roURLTransfer")
    colonRX = CreateObject("roRegEx", ":", "")
    timestampRX = CreateObject("roRegEx", "\[(timestamp|cache_breaker)\]", "i")
    dt = CreateObject("roDateTime")
    timestamp = dt.AsSeconds().ToStr()
    
    for each ad in xml.ad
      if m.debug then print "NWM_VAST: processing ad"

      newAd = {
        video: {
          streamFormat: "mp4"
          streams: []
          trackingEvents: []
          impressions: []
        }
        companionAds: []
      }
      
      ' wrappers are handled as a redirect
      ' video assets are sometimes subordinate to the <inline> tag
      ' and sometimes subordinate to the <linear> tag
      ' each of these variants defines tracking events differently as well
      
      ' follow any VAST redirects
      while true
        ' collect any impressions in this VAST before we process the redirect
        if ad.wrapper.impression.Count() > 0
          for each url in ad.wrapper.impression
            newAd.video.trackingEvents.Push({
              time: 0
              url:  timestampRX.Replace(ValidStr(url.GetText()), timestamp)
            })
          next
          for each url in xml.wrapper.wrapper.impression.url
            newAd.video.trackingEvents.Push({
              time: 0
              url:  timestampRX.Replace(ValidStr(url.GetText()), timestamp)
            })
          next
        end if
    
        ' collect any tracking events in this VAST before we process the redirect
        for each trackingEvent in ad.wrapper.creatives.creative.linear.trackingEvents.tracking
          if ValidStr(trackingEvent.GetText()) <> ""
            newAd.video.trackingEvents.Push({
              timing: UCase(ValidStr(trackingEvent@event))
              time:   0
              url:  timestampRX.Replace(ValidStr(trackingEvent.GetText()), timestamp)
            })
          end if
          for each url in trackingEvent.url
            newAd.video.trackingEvents.Push({
              timing: UCase(ValidStr(trackingEvent@event))
              time:   0
              url:  timestampRX.Replace(ValidStr(url.GetText()), timestamp)
            })
          next
        next
    
        ' follow the redirect
        ' some URLs need a timestamp injected
        url = invalid
        if ad.wrapper.vastAdTagURI.Count() > 0
          if ad.wrapper.vastAdTagURI.url.Count() > 0
            url = ValidStr(ad.wrapper.vastAdTagURI.url.GetText())
          else
            url = ValidStr(ad.wrapper.vastAdTagURI.GetText())
          end if
        else if ad.wrapper.VASTAdTagURL.Count() > 0
          ' this method is not part of the VAST 2.0 spec as far as I can tell
          ' but I have seen at least one provider doing it this way
          if ad.wrapper.VASTAdTagURL.url.Count() > 0
            url = ValidStr(ad.wrapper.VASTAdTagURL.url.GetText())
          else
            url = ValidStr(ad.wrapper.VASTAdTagURL.GetText())
          end if
        end if
        
        if url <> invalid
          url = timestampRX.Replace(url, timestamp)

          if url.InStr(0, "https") = 0
            ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
            ut.InitClientCertificates()
          end if
          xfer.SetURL(url)
          setURL = xfer.GetURL()
          if m.debug then print "NWM_VAST: processing wrapper: " + setURL
          if setURL = ""
            if m.debug then print "NWM_VAST: ***ERROR*** SetURL failed for " + url
          end if
          raw = xfer.GetToString()

          xml.Parse(raw)
          if xml.ad.Count() > 0
            ad = xml.ad
          else
            if m.debug then print "NWM_VAST: no ads found in XML"
            exit while
          end if
        else
          exit while
        end if
      end while
      
      m.id = ValidStr(ad@id)
  
      if ad.inLine.video.Count() > 0
        creative = ad.inLine.video[0]
        
        for each mediaFile in creative.mediaFiles.mediaFile
          ' step through the various media files for the creative
          mimeType = LCase(ValidStr(mediaFile@type))
          if m.supportedMimeTypes.DoesExist(mimeType) or returnUnsupportedVideo
            newStream = {
              url: ValidStr(mediaFile.url.GetText()).Trim()
              height: StrToI(ValidStr(mediaFile@height))
            }

            if mimeType = "application/json"
              newStream.provider = "iroll"
            end if
            
            if StrToI(ValidStr(mediaFile@bitrate)) > 0
              newStream.bitrate = StrToI(ValidStr(mediaFile@bitrate))
            end if
            
            if m.debug
              print "NWM_VAST: found video"
              print "NWM_VAST: - type: " + mimeType
              print "NWM_VAST: - url: " + newStream.url
              if newStream.bitrate <> invalid
                print "NWM_VAST: - bitrate: " + newStream.bitrate.ToStr()
              end if
            end if
            newAd.video.streams.Push(newStream)
          else
            if m.debug then print "NWM_VAST: unsupported video type: " + ValidStr(mediaFile@type)
          end if
        next
    
        if newAd.video.streams.Count() > 0
          ' we found playable content
          durationBits = colonRX.Split(ValidStr(creative.duration.GetText()))
          length = 0
          secondsPerUnit = 1
          i = durationBits.Count() - 1
          while i >= 0
            length = length + (StrToI(durationBits[i]) * secondsPerUnit)
            secondsPerUnit = secondsPerUnit * 60
            i = i - 1
          end while
          if length > 0
            newAd.video.length = length
          else
            if m.debug then print "NWM_VAST: error. failed to calculate video duration"
          end if
          
          if ad.inline.impression.Count() > 0
            for each url in ad.inline.impression
              if m.debug then print "NWM_VAST: processing impression"
              newAd.video.trackingEvents.Push({
                time: 0
                url:  timestampRX.Replace(ValidStr(url.GetText()), timestamp)
              })
            next
            for each url in ad.inline.impression.url
              if m.debug then print "NWM_VAST: processing impression"
              newAd.video.trackingEvents.Push({
                time: 0
                url:  timestampRX.Replace(ValidStr(url.GetText()), timestamp)
              })
            next
          end if
          
          for each trackingEvent in ad.inline.trackingEvents.tracking
            if ValidStr(trackingEvent.GetText()) <> ""
              newAd.video.trackingEvents.Push({
                timing: UCase(ValidStr(trackingEvent@event))
                url:  timestampRX.Replace(ValidStr(trackingEvent.GetText()), timestamp)
              })
            end if
            for each url in trackingEvent.url
              newAd.video.trackingEvents.Push({
                timing: UCase(ValidStr(trackingEvent@event))
                url:  timestampRX.Replace(ValidStr(url.GetText()), timestamp)
              })
            next
          next
        end if
      else 
        for each creative in ad.inLine.creatives.creative
          if creative.linear.mediaFiles.Count() > 0
            creative = creative.linear
            
            for each mediaFile in creative.mediaFiles.mediaFile
              ' step through the various media files for the creative
              mimeType = LCase(ValidStr(mediaFile@type))
              if m.supportedMimeTypes.DoesExist(mimeType) or returnUnsupportedVideo
                newStream = {
                  url: ValidStr(mediaFile.GetText()).Trim()
                  height: StrToI(ValidStr(mediaFile@height))
                }

                if mimeType = "application/json"
                  newStream.provider = "iroll"
                end if

                if StrToI(ValidStr(mediaFile@bitrate)) > 0
                  newStream.bitrate = StrToI(ValidStr(mediaFile@bitrate))
                end if
                
                if m.debug
                  print "NWM_VAST: found video"
                  print "NWM_VAST: - type: " + mimeType
                  print "NWM_VAST: - url: " + newStream.url
                  if newStream.bitrate <> invalid
                    print "NWM_VAST: - bitrate: " + newStream.bitrate.ToStr()
                  end if
                end if
                newAd.video.streams.Push(newStream)
              else
                if m.debug then print "NWM_VAST: unsupported video type: " + ValidStr(mediaFile@type)
              end if
            next
        
            if newAd.video.streams.Count() > 0
              ' we found playable content
              
              durationBits = colonRX.Split(ValidStr(creative.duration.GetText()))
              length = 0
              secondsPerUnit = 1
              i = durationBits.Count() - 1
              while i >= 0
                length = length + (StrToI(durationBits[i]) * secondsPerUnit)
                secondsPerUnit = secondsPerUnit * 60
                i = i - 1
              end while
              if length > 0
                newAd.video.length = length
              else
                if m.debug then print "NWM_VAST: error. failed to calculate video duration"
              end if
              
              if ad.inline.impression.Count() > 0
                for each url in ad.inline.impression
                  if m.debug then print "NWM_VAST: processing impression"
                  newAd.video.trackingEvents.Push({
                    time: 0
                    url:  timestampRX.Replace(ValidStr(url.GetText()), timestamp)
                  })
                  newAd.video.impressions.Push(timestampRX.Replace(ValidStr(url.GetText()), timestamp)) ' to support some partners' need to fire events for videos that aren't actually played
                next
                for each url in ad.inline.impression.url
                 if m.debug then print "NWM_VAST: processing impression"
                 newAd.video.trackingEvents.Push({
                    time: 0
                    url:  timestampRX.Replace(ValidStr(url.GetText()), timestamp)
                  })
                  newAd.video.impressions.Push(timestampRX.Replace(ValidStr(url.GetText()), timestamp)) ' to support some partners' need to fire events for videos that aren't actually played
                next
              end if
              
              for each trackingEvent in creative.trackingEvents.tracking
                if ValidStr(trackingEvent.GetText()) <> ""
                  newAd.video.trackingEvents.Push({
                    timing: UCase(ValidStr(trackingEvent@event))
                    url:  timestampRX.Replace(ValidStr(trackingEvent.GetText()), timestamp)
                  })
                end if
                for each url in trackingEvent.url
                  newAd.video.trackingEvents.Push({
                    timing: UCase(ValidStr(trackingEvent@event))
                    url:  timestampRX.Replace(ValidStr(url.GetText()), timestamp)
                  })
                next
              next
            end if
          else if creative.companionAds.Count() > 0
            for each companion in creative.companionAds.companion
              newCompanion = {
                width:          StrToI(ValidStr(companion@width))
                height:         StrToI(ValidStr(companion@height))
                trackingEvents: []
              }
              
              if m.debug then print "NWM_VAST: found companion"
              if companion.staticResource.Count() > 0
                companionType = LCase(ValidStr(companion.staticResource[0]@creativeType))
                if m.debug then print "NWM_VAST: - type: " + companionType
                if companionType = "image/jpeg" or companionType = "image/png"
                  newCompanion.imageURL = ValidStr(companion.staticResource[0].GetText())
                  if m.debug then print "NWM_VAST: - url: " + newCompanion.imageURL
                end if
              end if
              
              for each trackingEvent in companion.trackingEvents.tracking
                newCompanion.trackingEvents.Push(timestampRX.Replace(ValidStr(trackingEvent.GetText()), timestamp))
              next
              
              if companion.companionClickThrough.Count() > 0
                newCompanion.clickThrough = ValidStr(companion.companionClickThrough[0].GetText())
              end if
              
              newAd.companionAds.Push(newCompanion)
            next
          end if
        next
      end if
      
      if newAd.video.streams.Count() > 0 and newAd.video.length <> invalid
        ' if we found a playable ad, calculate the firing times for the tracking events
        i = 0
        while i < newAd.video.trackingEvents.Count()
          trackingEvent = newAd.video.trackingEvents[i]
          
          ' try to fix any malformed URLs
          if normalizeURLs
            if m.debug then print "NWM_VAST: - before: " + trackingEvent.url
            trackingEvent.url = NormalizeURL(trackingEvent.url)
            if m.debug then print "NWM_VAST: - after: " + trackingEvent.url
          end if
  
          if trackingEvent.timing <> invalid
            time = invalid
            if trackingEvent.timing = "FIRSTQUARTILE"
              time = Int(newAd.video.length * 0.25)
            else if trackingEvent.timing = "MIDPOINT"
              time = Int(newAd.video.length * 0.5)
            else if trackingEvent.timing = "THIRDQUARTILE"
              time = Int(newAd.video.length * 0.75)
            else if trackingEvent.timing = "COMPLETE"
              ' fire two seconds before the end just in case the duration tag isn't exactly accurate
              time = newAd.video.length - 2
            else if trackingEvent.timing = "START"
              time = 0
            else if trackingEvent.timing = "CREATIVEVIEW"
              ' fire the creativeView at the same time as start.  it behaves similar to an impression event
              time = 0
            end if
            
            if time <> invalid
              if m.debug 
                print "NWM_VAST: processing tracking event"
                print "NWM_VAST: - type: " + trackingEvent.timing
                print "NWM_VAST: - firing time: " + time.ToStr() + "s"
              end if
              trackingEvent.time = time
              i = i + 1
            else
              ' purge any events we dont care about (mute, fullscreen, etc)
              newAd.video.trackingEvents.Delete(i)
            end if
          else
            i = i + 1
          end if
        end while
        
      end if
      'PrintAA(newAd)
      m.ads.Push(newAd)
    next

    if m.ads.Count() > 0
      ' backward compatibility with previous VAST implementations that only worked with single ads
      m.companionAds = m.ads[0].companionAds
      m.video = m.ads[0].video
    end if
  else
    if m.debug then print "NWM_VAST: input could not be parsed as XML"
  end if
  
  return result
end function

' for backward compatibility with older versions of the library
function NWM_VAST_GetPrerollFromURL(url)
  xfer = CreateObject("roURLTransfer")
  xfer.SetURL(url)
  raw = xfer.GetToString()
  m.Parse(raw)
  
  return m.video
end function
