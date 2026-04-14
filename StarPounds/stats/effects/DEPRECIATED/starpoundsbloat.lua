function init()
  if effect.duration() > 0 then
    world.sendEntityMessage(entity.id(), "starPounds.stomach.feed", effect.duration(), "bloat")
  end
  world.sendEntityMessage(entity.id(), "queueRadioMessage", {
    messageId = "bloatWarning",
    important = true,
    unique = false,
    text = "^red;------------WARNING------------\n^reset;^#ccbbff;StarPounds^reset; or an addon has applied the depreciated ^red;starpoundsbloat^reset; status effect.\nPlease inform the mod author(s).",
  })
end

function update()
  effect.expire()
end
