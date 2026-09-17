--TY Silver Sokolova
function init()
  storage.combination = storage.combination or config.getParameter("combination")
  storage.entry = storage.entry or {}
  correctCombinationEntered = false
end


function onInputNodeChange(args)
  if args.level then
    storage.entry = storage.entry or {}
    storage.entry[#storage.entry + 1] = args.node + 1
  end

  if storage.entry[#storage.entry] ~= storage.combination[#storage.entry] then
    storage.entry = {}
    correctCombinationEntered = false
  end
  correctCombinationEntered = #storage.entry == #storage.combination
  object.setOutputNodeLevel(0, correctCombinationEntered)
end