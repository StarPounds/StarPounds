function init()
  if effect.duration() > 0 then
    world.sendEntityMessage(entity.id(), "applyStatusEffect", "starpoundsdigesting", effect.duration(), effect.sourceEntity())
  end
  world.sendEntityMessage(entity.id(), "queueRadioMessage", {
    messageId = "digestingWarning",
    important = true,
    unique = false,
    text = "^red;------------WARNING------------\n^reset;^#ccbbff;StarPounds^reset; or an addon has applied the depreciated ^red;digesting^reset; status effect.\nPlease inform the mod author(s).",
  })
end

function update()
  effect.expire()
end
