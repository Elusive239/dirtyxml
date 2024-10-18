# DXML
Starting as a port of [littlexml](https://github.com/jonahisadev/littlexml) (originally written by 
[jonahisadev](jonahisadev) in C) to [C3](https://c3-lang.org/) for personal reasons, dxml (Dirty-XML) 
tries to be a slight improvement on littlexml by making use of C3s' features and standard library
(using helpful things like C3s builtin Allocators, Strings, Interfaces, Faults, Methods, etc)!  

While I could have simply made some bindings for it there were some changes I wanted to make to make it play nicer with C3, so I ended up just rewriting it.