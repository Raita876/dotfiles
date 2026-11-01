def source:
  if type == "string" then . else .source end;
def managed:
  if type != "string" then false
  elif startswith($storeDir + "/") then
    ltrimstr($storeDir + "/")
    | test("^[0-9a-z]{32}-pi-extensions-node-modules-[^/]+/node_modules/")
  else false end;

[$static.packages[] | source] as $declared
| $dynamic
| if has("packages") then
    .packages |= map(select(
      source as $source
      | ($source | managed | not) or ($declared | index($source) != null)
    ))
  else . end
