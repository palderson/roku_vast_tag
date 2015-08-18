REM Functions in this file:
REM     isnonemptystr
REM     isnullorempty
REM     strtobool
REM     itostr
REM     strTrim
REM     strTokenize
REM     strReplace
REM     

'******************************************************
'isnonemptystr
'
'Determine if the given object supports the ifString interface
'and returns a string of non zero length
'******************************************************
Function isnonemptystr(obj)
    return ((obj <> invalid) AND (GetInterface(obj, "ifString") <> invalid) AND (Len(obj) > 0))
End Function


'******************************************************
'isnullorempty
'
'Determine if the given object is invalid or supports
'the ifString interface and returns a string of zero length
'******************************************************
Function isnullorempty(obj)
    return ((obj = invalid) OR (GetInterface(obj, "ifString") = invalid) OR (Len(obj) = 0))
End Function


'******************************************************
'strtobool
'
'Convert string to boolean safely. Don't crash
'Looks for certain string values
'******************************************************
Function strtobool(obj As dynamic) As Boolean
    if obj = invalid return false
    if type(obj) <> "roString" and type(obj) <> "String" return false
    o = strTrim(obj)
    o = Lcase(o)
    if o = "true" return true
    if o = "t" return true
    if o = "y" return true
    if o = "1" return true
    return false
End Function

'******************************************************
'booltostr
'
'Converts a boolean value to a cannonical string value
'******************************************************
Function booltostr(bool As Boolean) As String
    if bool = true then return "true"
    return "false"
End Function

'******************************************************
'itostr
'
'Convert int to string. This is necessary because
'the builtin Stri(x) prepends whitespace
'******************************************************
Function itostr(i As Integer) As String
    str = Stri(i)
    return strTrim(str)
End Function


'******************************************************
'Trim a string
'******************************************************
Function strTrim(str As String) As String
    st=CreateObject("roString")
    st.SetString(str)
    return st.Trim()
End Function


'******************************************************
'Tokenize a string. Return roList of strings
'******************************************************
Function strTokenize(str As String, delim As String) As Object
    st=CreateObject("roString")
    st.SetString(str)
    return st.Tokenize(delim)
End Function


'******************************************************
'Replace substrings in a string. Return new string
'******************************************************
Function strReplace(basestr As String, oldsub As String, newsub As String) As String
    newstr = ""

    i = 1
    while i <= Len(basestr)
        x = Instr(i, basestr, oldsub)
        if x = 0 then
            newstr = newstr + Mid(basestr, i)
            exit while
        endif

        if x > i then
            newstr = newstr + Mid(basestr, i, x-i)
            i = x
        endif

        newstr = newstr + newsub
        i = i + Len(oldsub)
    end while

    return newstr
End Function

'
' NWM 130811
' attempt to parse, decode, and re-encode a URL to fix any poorly encoded characters 
' that might cause roURLTransfer.SetURL() to fail
'
function NormalizeURL(url)
  result = url
  
  xfer = CreateObject("roURLTransfer")
  xfer.SetURL(url)
  if xfer.GetURL() = url
    ? "NormalizeURL: SetURL() succeeded, normalization not necessary"
    return result
  end if
  
  bits = url.Tokenize("?")
  if bits.Count() > 1
    result = bits[0] + "?"
    
    pairs = bits[1].Tokenize("&")
    for each pair in pairs
      keyValue = pair.Tokenize("=")

      key = xfer.UnEscape(keyValue[0])
      ? "NormalizeURL: un-escaped key " + key
      key = xfer.Escape(key)
      ? "NormalizeURL: re-escaped key " + key
      
      result = result + key

      if keyValue.Count() > 1
        value = xfer.UnEscape(keyValue[1])
        ? "NormalizeURL: un-escaped value " + value
        value = xfer.Escape(value)
        ? "NormalizeURL: re-escaped value " + value
        
        result = result + "=" + value
      end if

      result = result + "&"
    next
    
    result = result.Left(result.Len() - 1)
    ? "NormalizeURL: normalized URL " + result

    xfer.SetURL(result)
    if xfer.GetURL() = result
      ? "NormalizeURL: SetURL() succeeded with normalized URL"
    else
      ? "NormalizeURL: ***ERROR*** SetURL() failed with normalized URL"
    end if
  end if
  
  return result
end function
