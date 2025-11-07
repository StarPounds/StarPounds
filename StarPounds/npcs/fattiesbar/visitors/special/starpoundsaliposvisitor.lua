local init_old = init
starPounds_hasInteracted = {}

function init()
  local sayToEntity_old = sayToEntity
  function sayToEntity(args, board)
    if args.dialogType == "dialog.converse" then
      -- Always say the blessing line, and bless them on the first interaction (60 second reset).
      if not starPounds_hasInteracted[args.entity] or (os.time() - starPounds_hasInteracted[args.entity]) > 60 then
        args = copy(args)
        args.dialogType = "dialog.bless"
        -- Bless them.
        starPounds_hasInteracted[args.entity] = os.time()
        world.sendEntityMessage(args.entity, "starPounds.addEffect", "alipos")
      end
    end
    -- Do old stuff.
    return sayToEntity_old(args, board)
  end
  init_old()
end
