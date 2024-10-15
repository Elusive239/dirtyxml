module xml;
import std::io;
import std::collections;
import std::io::path;
// import std::io::stream;

struct XMLDocument (Printable)
{
    XMLNode* root;
    String version;
    String encoding;
}

struct XMLAttribute (Printable)
{
    String key;
    String value;
}

struct XMLNode (Printable)
{
    String tag;
    String inner_text;
    XMLNode* parent;
    XMLAttributeList attributes;
    XMLNodeList children;
}

enum TagType
{
    TAG_START,
    TAG_INLINE,
}

fault XMLError{
    TAG_PARSING,
    TEXT_OUTSIDE_NODE,
    MISMATCHED_TAGS,
    CLOSING_UNOPENED_NODE,
}

//decided to use C3s built in lists!
def XMLAttributeList = List(<XMLAttribute*>);
def XMLNodeList = List(<XMLNode*>);

//Functions

fn void XMLDocument.free(&self, Allocator allocator = allocator::heap()){
    if(self.encoding.len > 0) allocator::free(allocator, self.encoding);
    if(self.version.len > 0) allocator::free(allocator, self.version);
    if(self.root != null) self.root.free();
}

fn void XMLNode.free(&self, Allocator allocator = allocator::heap()){
    for(int i = 0; i < self.attributes.len(); i++) self.attributes[i].free(allocator);
    self.attributes.free();
    for(int i = 0; i < self.children.len(); i++) self.children[i].free();
    self.children.free();
    if(self.tag.len > 0) allocator::free(allocator, self.tag);
    if(self.inner_text.len > 0) allocator::free(allocator, self.inner_text);
    allocator::free(allocator, self);
}

fn void XMLAttribute.free(&self, Allocator allocator = allocator::heap()){
    if(self.key.len   != 0) allocator::free(allocator, self.key);
    if(self.value.len != 0) allocator::free(allocator, self.value);
    allocator::free(allocator, self);
}

/*OPENING/CREATING DOCUMENTS*/

fn XMLNode* new_node(XMLNode* parent, Allocator allocator = allocator::heap()){
    XMLNode* node   = (XMLNode*) allocator::calloc(allocator, XMLNode.sizeof);
    node.parent     = parent;
    node.tag        = "";
    node.inner_text = "";
    node.attributes.new_init(allocator: allocator);
    node.children.new_init(allocator: allocator);
    if (parent != null) parent.children.push(node);
    return node;
}

fn String XMLNode.find_attribute(XMLNode* node, String key){
    for(int i =0; i < node.attributes.len(); i++){
        String other = node.attributes[i].key[0..(node.attributes[i].key.len-2)];
        if(str_equal(key, other)) return node.attributes[i].value;
    }
    return "";
}

fn void! XMLDocument.load_from_stream(XMLDocument* doc, InStream stream, Allocator allocator = allocator::heap()){
    usz len = io::available(stream)! ;
    char* buffer = allocator::malloc(allocator, char.sizeof * len);
    stream.read(buffer[:len])!;
    doc.load(buffer[:len])!;
    allocator::free(allocator, buffer);
}

fn void! XMLDocument.load_from_path(XMLDocument* doc, Path path, Allocator allocator = allocator::heap()){
    doc.load_file(path.str_view(), allocator)!;
}

fn void! XMLDocument.load_file(XMLDocument* doc, String path, Allocator allocator = allocator::heap()){
    char[] file = file::load_new(path, allocator)!;
    doc.load(file)!;
    allocator::free(allocator, file);
}

fn void! XMLDocument.load(XMLDocument* doc, char[] file, Allocator allocator = allocator::heap()){
    doc.root = new_node(null, allocator);

    char[256] lex;
    int lexi = 0;
    int i = 0;

    for(i; i < file.len && file[i] != '<'; ++i); //skip to first node
    XMLNode* current = doc.root;
    while(i < file.len){
        if(file[i] == '<'){
            lex[lexi] = 0;
            //inner text
            if(lexi > 0){
                if(current == null){
                    io::eprintfn("[ERROR] Text outside of document.");
                    return XMLError.TEXT_OUTSIDE_NODE?;
                }

                current.inner_text = copy_zfa(&lex, lexi, allocator);
                lexi = 0;
            }
            
            //end of tag
            if(file[i+1] == '/'){
                i+=2;
                while(file[i] != '>'){
                    lex[lexi++] = file[i++];
                }
                lex[lexi] = 0;
                if(current == null){
                    io::eprintfn("[ERROR] Already at the root!" );
                    return XMLError.CLOSING_UNOPENED_NODE?;
                }
                if (compare_char_arr(current.tag, &lex, lexi)){
                    io::eprintfn("[ERROR] Mismatched tags (%s != %s)", current.tag, lex[0..lexi]);
                    return XMLError.MISMATCHED_TAGS?;
                }
                current = current.parent;
                i++;
                lexi = 0;
                continue;
            }

            //special nodes
            if(file[i+1] == '!' && file[i+2] == '-' && file[i+3] == '-'){
                while(file[i] != ' ' && file[i] != '>') lex[lexi++] = file[i++];
                lex[lexi] = 0;

                if(!compare_char_arr("<!--", &lex, lexi)){
                    lex[lexi] = 0;
                    while(!(file[i-2] == '-' && file[i-1] == '-' && file[i] == '>')){
                        lex[lexi++] = file[i++];
                        lex[lexi] = 0;
                    }
                    continue;
                }
            }

            if(file[i+1] == '?'){
                while(file[i] != ' ' && file[i] != '>') lex[lexi++] = file[i++];
                lex[lexi] = 0;
                if(!compare_char_arr("<?xml", &lex, lexi)){
                    lexi = 0;
                    XMLNode* desc = new_node(null, allocator);
                    

                    parse_attributes(&lex, &lexi, file, &i, desc, allocator)!;
                    doc.version = desc.find_attribute("version").copy(allocator);
                    doc.encoding = desc.find_attribute("encoding").copy(allocator);
                    desc.free();
                    continue;
                }
            }

            //set current node
            current = new_node(current, allocator);

            //start tag
            i++;
            if( parse_attributes(&lex, &lexi, file, &i, current, allocator)! == TagType.TAG_INLINE){
                current = current.parent;
                i++;
                continue;
            }
            
            lex[lexi] = 0;
            if( current.tag.len == 0){
                current.tag = copy_zfa(&lex, lexi, allocator);
            }
            lexi = 0;
            i++;
            continue;
        }
        else {
            lex[lexi++] = file[i++];
        }
    }
}

fn TagType! parse_attributes(char[] lex, int* xlexi, char[] file, int* xi, XMLNode* current, Allocator allocator = allocator::heap()){
    int i = *xi;
    int lexi = *xlexi;
    XMLAttribute* current_attribute;
    while(file[i] != '>'){
        lex[lexi++] = file[i++];
        //tag name
        if(file[i] == ' ' && current.tag.len == 0){
            lex[lexi] = 0;
            current.tag = copy_zfa(lex, lexi, allocator);
            lexi = 0;
            i++;
            continue;
        }
        //ignore spaces (usually)
        if(lex[lexi-1] == ' '){
            lexi--;
        }
        //attribute key
        if(file[i] == '='){
            current_attribute = (XMLAttribute*) allocator::calloc(allocator, XMLAttribute.sizeof);
            lex[lexi] = 0;
            current_attribute.key = copy_zfa(lex, lexi, allocator);
            lexi = 0;
            continue;
        }
        //attribute value
        if(file[i] == '\"'){
            if(current_attribute.key.len == 0){
                io::eprintfn("[ERROR] Value has no key.");
                return XMLError.TAG_PARSING?;
            }
            lexi = 0;
            i++;
            while(file[i] != '\"'){
                lex[lexi++] = file[i++];
            }
            lex[lexi] = 0;
            current_attribute.value = copy_zfa(lex, lexi, allocator);
            current.attributes.push(current_attribute);
            current_attribute = null;
            lexi = 0;
            i++;
            continue;
        }
        if (file[i-1] == '/' && file[i] == '>'){
            lex[lexi] = 0;
            if(current.tag.len == 0){
                current.tag = copy_zfa(lex, lexi, allocator);
                i++;
            }
            lexi = 0;
            *xi = i;
            *xlexi = lexi;
            return TagType.TAG_INLINE;
        }
    }
    *xi = i;
    *xlexi = lexi;
    return TagType.TAG_START;
}

macro String copy_zfa(char[] arr, int len, Allocator allocator = allocator::heap())  @private{
    String zstr = ((String)arr[0..len-1]).copy(allocator);
    return zstr;
}

macro bool compare_char_arr(String tag, char[] buffer, int len)  @private{
    for(int i = 0; i < len; i++){
        if(tag[i] - buffer[i] != 0){
            return true;
        }
    }
    return false;
}

macro bool str_equal(String a, String b) @private{
    for(int i = 0; i < b.len; i++){
        if(a[i] != b[i]) return false;
    }
    return true;
}

/*SAVING DOCUMENTS*/


fn void! XMLDocument.write_to_file(XMLDocument* doc, String path, Allocator allocator = allocator::heap()){
    File file = file::open(path, "w")!;
    file.write(doc.to_string(allocator))!;
    file.close()!;
}

fn void! XMLDocument.write_to_path(XMLDocument* doc, Path path, Allocator allocator = allocator::heap()){
    doc.write_to_file(path.str_view(), allocator)!;
}

fn String XMLDocument.to_string(XMLDocument* doc, Allocator allocator = allocator::heap()) @dynamic{
    if(doc.root == null){
        io::eprintfn("[ERROR] No document loaded!");
        return "";
    }

    DString dstr = dstring::new_with_capacity(100, allocator);
    defer dstr.free();
    if(doc.encoding.len > 0 || doc.version.len > 0) {
        //doing copies because they may be freed later..
        String encoding = (doc.encoding.len > 0 ? doc.encoding : "UTF-8").copy(allocator);
        String version = (doc.version.len > 0 ? doc.version : "1.0").copy(allocator);
        dstr.appendfn( "<?xml version=\"%s\" encoding=\"%s\"?>", version, encoding);
    }
    //if no tag & the root has children, then there are multiple root nodes 
    //so we just skip to those instead of printing the empty one.
    if(doc.root.tag.len == 0 && doc.root.children.len() > 0){
		for(int i =0; i < doc.root.children.len(); i++){
			XMLNode* cnode = doc.root.children[i];
			dstr.append_node(cnode);
		}
	}else {
        dstr.append_node(doc.root);
    }
    return dstr.copy_str(allocator);
}

fn String XMLNode.to_string(XMLNode* node, Allocator allocator = allocator::heap()) @dynamic{
    DString dstr = dstring::new_with_capacity(100, allocator);
    defer dstr.free();
    dstr.append_node(node);
    return dstr.copy_str(allocator);
}

fn String XMLAttribute.to_string(XMLAttribute* attribute, Allocator allocator = allocator::heap()) @dynamic{
    DString dstr = dstring::new_with_capacity(100, allocator);
    defer dstr.free();
    dstr.appendf("%s=\"%s\"", attribute.key, attribute.value);
    return dstr.copy_str();
}

fn void DString.append_node(DString* dstr, XMLNode* node, int tabs = 1){
    const char TAB = '\t';
    for(int i =0; i < tabs - 1; i++) dstr.append_char(TAB);
    dstr.appendf("<%s", node.tag);
    dstr.append_tags(node);
    if(node.inner_text.len == 0 && node.children.len() == 0){ //inline nodes
        dstr.appendfn("/>");
        return;
    }
    dstr.append_inner_text(node, tabs);
    for(int i =0; i < node.children.len(); i++) dstr.append_node(node.children[i], tabs + 1);
    for(int i =0; i < tabs - 1; i++) dstr.append_char(TAB);
	dstr.appendfn("</%s>", node.tag);
}

macro void DString.append_tags(DString* dstr, XMLNode* node){
    for(int i =0; i < node.attributes.len(); i++){
		XMLAttribute* attribute = node.attributes.get(i);
		dstr.appendf (" %s", attribute);
	}
}

macro void DString.append_inner_text(DString* dstr, XMLNode* node, int tabs){
    const char TAB = '\t';
    String innerText = node.inner_text.trim(" \n\t\r\0");
    if(innerText.len > 0){
        dstr.appendfn(">");
        for(int i =0; i < tabs; i++) dstr.append_char(TAB);
        dstr.appendf("%s\n", innerText);
    }else{
        dstr.appendfn(">");
    }
}