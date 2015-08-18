sub PlayVideo(video)
	canvas = CreateObject("roImageCanvas")
	canvas.SetMessagePort(CreateObject("roMessagePort"))
	canvas.SetLayer(1, {color: "#000000"})
	canvas.Show()

  ' play the pre-roll
  adCompleted = true
  
  if video.preroll <> invalid
    adCompleted = ShowPreRoll(canvas, video.preroll)
  end if

  if adCompleted
    ' if the ad completed without the user pressing UP, play the content
    ShowVideoScreen(video)
  end if
	
	canvas.Close()
end sub

sub ShowVideoScreen(episode)
	screen = CreateObject("roVideoScreen")
	screen.SetMessagePort(CreateObject("roMessagePort"))
	screen.SetPositionNotificationPeriod(1)
	screen.SetContent(episode)
	screen.Show()

	while true
		msg = wait(0, screen.GetMessagePort())
		
		if msg <> invalid
			if msg.isScreenClosed()
				exit while
			end if
		end if
	end while

	screen.Close()
end sub

function ShowPreRoll(canvas, ad)
	result = true

	player = CreateObject("roVideoPlayer")
	' be sure to use the same message port for both the canvas and the player
	player.SetMessagePort(canvas.GetMessagePort())
  player.SetDestinationRect(canvas.GetCanvasRect())
  player.SetPositionNotificationPeriod(1)
  
  ' set up some messaging to display while the pre-roll buffers
  canvas.SetLayer(2, {text: "Your program will begin after this message"})
  canvas.Show()
  
	player.AddContent(ad)
	player.Play()
	
	while true
		msg = wait(0, canvas.GetMessagePort())
		
		if type(msg) = "roVideoPlayerEvent"
			if msg.isFullResult()
				exit while
			else if msg.isPartialResult()
				exit while
			else if msg.isRequestFailed()
			  print "isRequestFailed"
				exit while
			else if msg.isStatusMessage()
				if msg.GetMessage() = "start of play"
				  ' once the video starts, clear out the canvas so it doesn't cover the video
					canvas.ClearLayer(2)
					canvas.SetLayer(1, {color: "#00000000", CompositionMode: "Source"})
					canvas.Show()
				end if
			else if msg.isPlaybackPosition()
			  print "isPlaybackPosition: " + msg.GetIndex().ToStr()
			  for each trackingEvent in ad.trackingEvents
			    if trackingEvent.time = msg.GetIndex()
			      FireTrackingEvent(trackingEvent)
			    end if
			  next
			end if
		else if type(msg) = "roImageCanvasEvent"
      if msg.isRemoteKeyPressed()
        index = msg.GetIndex()
        if index = 2 or index = 0  '<UP> or BACK
          for each trackingEvent in ad.trackingEvents
            if trackingEvent.event = "CLOSE"
              FireTrackingEvent(trackingEvent)
            end if
          next

        	result = false
        	exit while
        end if
      end if
		end if
	end while
	
	player.Stop()
	return result
end function

function FireTrackingEvent(trackingEvent)
  result = true
  timeout = 3000
  timer = CreateObject("roTimespan")
  timer.Mark()
  port = CreateObject("roMessagePort")
  xfer = CreateObject("roURLTransfer")
  xfer.SetPort(port)

  xfer.SetURL(trackingEvent.url)
  print "~~~TRACKING: " + xfer.GetURL()
  ' have to do this synchronously so that we don't colide with 
  ' other tracking events firing at or near the same time
  if xfer.AsyncGetToString()
    event = wait(timeout, port)
    
    if event = invalid
      ' we waited long enough, moving on
      xfer.AsyncCancel()
      result = false
    else
      print "Req finished: " + timer.TotalMilliseconds().ToStr()
      print event.GetResponseCode().ToStr()
      print event.GetFailureReason()
    end if
  end if
  
  return result
end function

