-- UI sounds are switched off: button clicks and interface cues are silent.
-- The API stays so existing callers need no changes.
local UISound={}
function UISound.play() end
function UISound.init() end
return UISound
