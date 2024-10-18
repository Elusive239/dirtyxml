# DXML
Starting as a port of [littlexml](https://github.com/jonahisadev/littlexml) (originally written by 
[jonahisadev](jonahisadev) in C) to [C3](https://c3-lang.org/) for personal reasons, dxml (Dirty-XML) 
tries to be a slight improvement on littlexml by making use of C3s' features and standard library
(using helpful things like C3s builtin Allocators, Strings, Interfaces, Faults, Methods, etc)!  

# WHY?
While I could have simply made some bindings for littlexml, I wanted to make to make it play nicer with C3 and 
received some suggestions for making it a better user experience (like implementing In&OutStreams), so I ended up 
just reimplementing it. In the test folder there is some examples for using the "load" functions but I need to 
write proper examples actually using the different XMLNode, XMLAttribute, & XMLDocument structs in some way. 
