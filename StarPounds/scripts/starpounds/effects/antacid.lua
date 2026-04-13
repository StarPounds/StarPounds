local antacid = starPounds.moduleFunc("effects", "new")
-- Bloat cola reduces the duration.
function antacid:reduceDuration(duration)
  self.data.duration = math.max(self.data.duration - duration, 0)
end
-- Add the effect.
starPounds.modules.effects.effects.antacid = antacid
