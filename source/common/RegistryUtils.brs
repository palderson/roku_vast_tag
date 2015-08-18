REM This file has no dependencies on other common files.
REM
REM Functions in this file:
REM     RegRead
REM     RegWrite
REM     RegDelete
REM

'******************************************************
'Registry Helper Functions
'******************************************************
Function RegRead(key as String, section=invalid) as Dynamic
    if section = invalid then section = "Default"
    sec = CreateObject("roRegistrySection", section)
    if sec.Exists(key) then return sec.Read(key)
    return invalid
End Function

Function RegWrite(key as String, val as String, section=invalid) as Void
    if section = invalid then section = "Default"
    sec = CreateObject("roRegistrySection", section)
    sec.Write(key, val)
    sec.Flush() ' commit it
End Function

Function RegDelete(key as String, section=invalid) as Void
    if section = invalid then section = "Default"
    sec = CreateObject("roRegistrySection", section)
    sec.Delete(key)
    sec.Flush()
End Function

