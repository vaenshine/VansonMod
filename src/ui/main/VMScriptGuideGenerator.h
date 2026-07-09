#ifndef VMScriptGuideGenerator_h
#define VMScriptGuideGenerator_h

#import <Foundation/Foundation.h>
#import "VMScriptGuideStrings.h"
#import "../../../include/VMLocalization.h"

static inline NSString* VMGetGuideString(const std::string& key, const std::string& lang) {
    auto it = kScriptGuideStrings.find(key);
    if (it == kScriptGuideStrings.end()) {
        return [NSString stringWithUTF8String:key.c_str()];
    }
    
    auto langIt = it->second.find(lang);
    if (langIt == it->second.end()) {
        
        langIt = it->second.find("en");
        if (langIt == it->second.end()) {
            return [NSString stringWithUTF8String:key.c_str()];
        }
    }
    return [NSString stringWithUTF8String:langIt->second.c_str()];
}

static inline std::string VMGetCurrentLangCode() {
    NSString *currentLang = [[VMLocalization shared] currentLanguage];
    
    if ([currentLang isEqualToString:@"Auto"]) {
        NSArray *preferredLangs = [NSLocale preferredLanguages];
        if (preferredLangs.count > 0) {
            NSString *firstLang = preferredLangs.firstObject;
            if ([firstLang hasPrefix:@"zh-Hans"]) return "zh";
            if ([firstLang hasPrefix:@"zh-Hant"]) return "zh"; 
            if ([firstLang hasPrefix:@"zh"]) return "zh";
            if ([firstLang hasPrefix:@"ja"]) return "ja";
            if ([firstLang hasPrefix:@"ko"]) return "ko";
            if ([firstLang hasPrefix:@"ru"]) return "ru";
            if ([firstLang hasPrefix:@"es"]) return "es";
            if ([firstLang hasPrefix:@"vi"]) return "vi";
            if ([firstLang hasPrefix:@"pt"]) return "pt";
            if ([firstLang hasPrefix:@"fr"]) return "fr";
            if ([firstLang hasPrefix:@"de"]) return "de";
            if ([firstLang hasPrefix:@"th"]) return "th";
            if ([firstLang hasPrefix:@"ar"]) return "ar";
        }
        return "en";
    }
    
    if ([currentLang hasPrefix:@"zh"]) return "zh";
    if ([currentLang hasPrefix:@"ja"]) return "ja";
    if ([currentLang hasPrefix:@"ko"]) return "ko";
    if ([currentLang hasPrefix:@"ru"]) return "ru";
    if ([currentLang hasPrefix:@"es"]) return "es";
    if ([currentLang hasPrefix:@"vi"]) return "vi";
    if ([currentLang hasPrefix:@"pt"]) return "pt";
    if ([currentLang hasPrefix:@"fr"]) return "fr";
    if ([currentLang hasPrefix:@"de"]) return "de";
    if ([currentLang hasPrefix:@"th"]) return "th";
    if ([currentLang hasPrefix:@"ar"]) return "ar";
    
    return "en";
}

static inline NSString* VMGenerateScriptGuideHTML() {
    std::string lang = VMGetCurrentLangCode();
    
    #define S(key) VMGetGuideString(key, lang)
    
    NSMutableString *html = [NSMutableString string];
    
    [html appendString:@"<!DOCTYPE html>"
     "<html>"
     "<head>"
     "    <meta charset=\"UTF-8\">"
     "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">"
     "    <style>"
     "        :root {"
     "            --primary: #0a84ff; --secondary: #5e5ce6; --success: #32d74b; --warning: #ff9f0a; --danger: #ff453a;"
     "            --bg: #1c1c1e; --card: #2c2c2e; --text: #ffffff; --text-dim: #8e8e93; --code-bg: #121212;"
     "        }"
     "        body { font-family: -apple-system, system-ui, sans-serif; background: var(--bg); color: var(--text); margin: 0; padding: 16px; font-size: 14px; line-height: 1.5; }"
     "        .header-center { text-align: center; margin-bottom: 30px; }"
     "        .header-center h1 { font-size: 32px; font-weight: 900; color: var(--primary); margin-bottom: 5px; letter-spacing: -1px; }"
     "        .h5gg-support { border: 1px dashed var(--success); padding: 15px; border-radius: 10px; font-size: 13px; color: var(--success); margin-bottom: 25px; background: rgba(50, 215, 75, 0.05); }"
     "        .section-title { font-size: 20px; font-weight: 700; margin: 28px 0 15px 0; color: var(--primary); border-bottom: 1px solid #3a3a3c; padding-bottom: 6px; }"
     "        .card { background: var(--card); border-radius: 12px; padding: 16px; margin-bottom: 20px; border: 1px solid #3a3a3c; position: relative; }"
     "        .title-row { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; }"
     "        .tag { font-size: 10px; padding: 2px 8px; border-radius: 5px; background: #48484a; color: #d1d1d6; font-weight: bold; }"
     "        .tag.blue { background: rgba(10, 132, 255, 0.2); color: var(--primary); }"
     "        .tag.purple { background: rgba(175, 82, 222, 0.2); color: #af52de; }"
     "        .tag.green { background: rgba(50, 215, 75, 0.2); color: var(--success); }"
     "        .tag.orange { background: rgba(255, 159, 10, 0.2); color: var(--warning); }"
     "        .title { font-weight: 600; font-size: 16px; }"
     "        .code-box { background: var(--code-bg); border-radius: 8px; padding: 15px; font-family: 'SF Mono', 'Menlo', monospace; font-size: 12px; color: #34c759; margin: 12px 0; overflow-x: auto; white-space: pre; border: 1px solid #1c1c1e; line-height: 1.6; }"
     "        .btn-group { display: flex; gap: 10px; margin-top: 12px; }"
     "        .btn { flex: 1; padding: 8px; border-radius: 8px; border: none; font-size: 12px; font-weight: 600; cursor: pointer; transition: 0.2s; }"
     "        .btn-copy { background: rgba(255,255,255,0.1); color: #fff; }"
     "        .btn-insert { background: var(--primary); color: #fff; }"
     "        .btn:active { transform: scale(0.95); opacity: 0.8; }"
     "        .scenario { font-size: 13px; color: var(--text-dim); padding: 10px; background: rgba(255,255,255,0.03); border-radius: 8px; border-left: 4px solid var(--primary); margin-top: 8px; }"
     "        .param-table { width: 100%; border-collapse: collapse; font-size: 12px; margin-top: 10px; }"
     "        .param-table th { text-align: left; color: var(--text-dim); padding: 6px; border-bottom: 1px solid #3a3a3c; }"
     "        .param-table td { padding: 6px; border-bottom: 1px solid #2c2c2e; color: #d1d1d6; }"
     "        .param-table code { background: #1c1c1e; padding: 2px 6px; border-radius: 4px; color: #ff9f0a; }"
     "    </style>"
     "</head>"
     "<body>"];
    
    [html appendString:@"<div class=\"header-center\"><h1>VansonModScript</h1></div>"];
    
    [html appendFormat:@"<div class=\"h5gg-support\">%@</div>", S("tips_content")];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_1")];
    [html appendString:@"<div class=\"card\">"];
    [html appendString:@"<div class=\"title-row\"><span class=\"tag blue\">SEARCH</span><span class=\"title\">vm.search</span></div>"];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_search")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th></tr>", S("th_param"), S("th_desc")];
    [html appendFormat:@"<tr><td><code>value</code></td><td>%@</td></tr>", S("param_value")];
    [html appendFormat:@"<tr><td><code>type</code></td><td>%@</td></tr>", S("param_type")];
    [html appendFormat:@"<tr><td><code>from</code></td><td>%@</td></tr>", S("param_from")];
    [html appendFormat:@"<tr><td><code>to</code></td><td>%@</td></tr></table>", S("param_to")];
    [html appendFormat:@"<div class=\"code-box\" id=\"code-search\">%@\nvm.search('100', 'I32');\n\n%@\nvm.search('100', 'I32', '0x100000000', '0x200000000');</div>", S("comment_basic_search"), S("comment_search_range")];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-search')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-search')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_2")];
    [html appendString:@"<div class=\"card\">"];
    [html appendString:@"<div class=\"title-row\"><span class=\"tag green\">REFINE</span><span class=\"title\">vm.refine</span></div>"];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_refine")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th></tr>", S("th_param"), S("th_desc")];
    [html appendFormat:@"<tr><td><code>value</code></td><td>%@</td></tr>", S("param_filter_value")];
    [html appendFormat:@"<tr><td><code>type</code></td><td>%@</td></tr>", S("param_type")];
    [html appendFormat:@"<tr><td><code>mode</code></td><td>%@</td></tr></table>", S("param_mode")];
    [html appendFormat:@"<div class=\"code-box\" id=\"code-refine\">%@\nvm.refine('80', 'I32', 'eq');\n\n%@\nvm.refine('10', 'I32', 'inc');\n\n%@\nvm.refine('5', 'I32', 'dec');\n\n%@\nvm.refine('0', 'I32', 'chg');\n\n%@\nvm.refine('50', 'I32', 'gt');\n\n%@\nvm.refine('200', 'I32', 'lt');</div>", 
        S("comment_exact_match"), S("comment_value_increased"), S("comment_value_decreased"), 
        S("comment_value_changed"), S("comment_greater_than"), S("comment_less_than")];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-refine')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-refine')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_3")];
    [html appendString:@"<div class=\"card\">"];
    [html appendString:@"<div class=\"title-row\"><span class=\"tag purple\">FUZZY</span><span class=\"title\">vm.searchFuzzy</span></div>"];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_fuzzy")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th></tr>", S("th_param"), S("th_desc")];
    [html appendFormat:@"<tr><td><code>type</code></td><td>%@</td></tr></table>", S("param_type")];
    [html appendString:@"<div class=\"code-box\" id=\"code-fuzzy\">"];
    [html appendString:@"vm.searchFuzzy('I32');\n\nvm.refine('0', 'I32', 'chg');\n\nvm.refine('0', 'I32', 'gt');"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-fuzzy')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-fuzzy')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_4")];
    [html appendString:@"<div class=\"card\">"];
    [html appendString:@"<div class=\"title-row\"><span class=\"tag purple\">GROUP</span><span class=\"title\">vm.searchGroup</span></div>"];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_group")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th></tr>", S("th_param"), S("th_desc")];
    [html appendFormat:@"<tr><td><code>values</code></td><td>%@</td></tr>", S("param_values_expr")];
    [html appendFormat:@"<tr><td><code>defaultType</code></td><td>%@</td></tr></table>", S("param_default_type")];
    [html appendString:@"<div class=\"code-box\" id=\"code-group\">"];
    [html appendString:@"vm.searchGroup('100; 200; 300', 'I32');\n\nvm.searchGroup('100 I32; 0.5 F32; 10 I8', 'I32');\n\nvm.searchGroup('100; 200::48', 'I32');\n\nvm.searchGroup('1; *; 3::50', 'I32');\n\nvm.searchGroup('4:100 4:* 4:50', 'I32');\n\nvm.search('4:100 w:8 4:50', 'I32');\n\nvm.searchGroup('100 I32; 120.5 F32; 0x106b0d I64::48', 'I32');"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-group')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-group')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_5")];
    [html appendString:@"<div class=\"card\">"];
    [html appendString:@"<div class=\"title-row\"><span class=\"tag orange\">NEARBY</span><span class=\"title\">vm.nearby</span></div>"];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_nearby")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th></tr>", S("th_param"), S("th_desc")];
    [html appendFormat:@"<tr><td><code>value</code></td><td>%@</td></tr>", S("param_value")];
    [html appendFormat:@"<tr><td><code>type</code></td><td>%@</td></tr>", S("param_type")];
    [html appendFormat:@"<tr><td><code>range</code></td><td>%@</td></tr></table>", S("param_range")];
    [html appendString:@"<div class=\"code-box\" id=\"code-nearby\">"];
    [html appendString:@"vm.nearby('100', 'I32', 50);\n\nvm.nearby('999', 'I32', 200);"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-nearby')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-nearby')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_6")];
    [html appendString:@"<div class=\"card\">"];
    [html appendString:@"<div class=\"title-row\"><span class=\"tag blue\">SIG</span><span class=\"title\">vm.searchSign</span></div>"];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_signature")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th></tr>", S("th_param"), S("th_desc")];
    [html appendFormat:@"<tr><td><code>signature</code></td><td>%@</td></tr>", S("param_signature")];
    [html appendFormat:@"<tr><td><code>from</code></td><td>%@</td></tr>", S("param_from")];
    [html appendFormat:@"<tr><td><code>to</code></td><td>%@</td></tr></table>", S("param_to")];
    [html appendString:@"<div class=\"code-box\" id=\"code-sig\">"];
    [html appendString:@"vm.searchSign('E0 03 ?? 2A');\n\nvm.searchSign('E0 03 1F 2A ?? ?? 80 52', '0x100000000', '0x200000000');"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-sig')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-sig')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_between")];
    [html appendString:@"<div class=\"card\">"];
    [html appendString:@"<div class=\"title-row\"><span class=\"tag green\">BETWEEN</span><span class=\"title\">vm.searchBetween</span></div>"];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_between")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th></tr>", S("th_param"), S("th_desc")];
    [html appendFormat:@"<tr><td><code>min</code></td><td>%@</td></tr>", S("param_between_min")];
    [html appendFormat:@"<tr><td><code>max</code></td><td>%@</td></tr>", S("param_between_max")];
    [html appendFormat:@"<tr><td><code>type</code></td><td>%@</td></tr></table>", S("param_type")];
    [html appendString:@"<div class=\"code-box\" id=\"code-between\">"];
    [html appendString:@"vm.searchBetween('90', '100', 'I32');\n\nvm.searchBetween('1.0', '5.0', 'F32');\n\nvm.searchBetween('1000', '9999', 'I32');"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-between')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-between')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    #undef S
    
    return html;
}

static inline NSString* VMGenerateScriptGuideHTML_Part2(NSMutableString *html, const std::string& lang) {
    #define S(key) VMGetGuideString(key, lang)
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_7")];
    [html appendString:@"<div class=\"card\">"];
    [html appendFormat:@"<div class=\"title-row\"><span class=\"tag green\">RESULTS</span><span class=\"title\">%@</span></div>", S("card_results_title")];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_results")];
    [html appendString:@"<div class=\"code-box\" id=\"code-results\">"];
    [html appendString:@"var count = vm.getResultsCount();\nvm.log('Results: ' + count);\n\nvar results = vm.getResults(10, 0);\nfor (var i = 0; i < results.length; i++) {\n    vm.log('Addr: ' + results[i].address + ' Val: ' + results[i].value);\n}\n\nvm.editAll('9999', 'I32');\n\nvm.write('888', 'I32', 0);\n\nvm.clear();"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-results')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-results')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendString:@"<div class=\"card\">"];
    [html appendFormat:@"<div class=\"title-row\"><span class=\"tag orange\">ADV</span><span class=\"title\">%@</span></div>", S("card_editall_adv_title")];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_editall_adv")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th><th>%@</th></tr>", S("th_syntax"), S("th_desc"), S("th_example")];
    [html appendFormat:@"<tr><td><code>N</code></td><td>%@</td><td>%@</td></tr>", S("filter_single_index"), S("filter_ex_single")];
    [html appendFormat:@"<tr><td><code>N,M,...</code></td><td>%@</td><td>%@</td></tr>", S("filter_multi_index"), S("filter_ex_multi")];
    [html appendFormat:@"<tr><td><code>N=M</code></td><td>%@</td><td>%@</td></tr>", S("filter_range"), S("filter_ex_range")];
    [html appendFormat:@"<tr><td><code>@XXX</code></td><td>%@</td><td>%@</td></tr>", S("filter_addr_suffix"), S("filter_ex_suffix")];
    [html appendFormat:@"<tr><td><code>||XXX</code></td><td>%@</td><td>%@</td></tr>", S("filter_value_contains"), S("filter_ex_contains")];
    [html appendFormat:@"<tr><td><code>//+N</code></td><td>%@</td><td>%@</td></tr></table>", S("filter_offset"), S("filter_ex_offset")];
    [html appendString:@"<div class=\"code-box\" id=\"code-editall-adv\">"];
    [html appendString:@"vm.editAll('999', 'I32', '1=10');\n\nvm.editAll('999', 'I32', '1,3,5');\n\nvm.editAll('999', 'I32', '@ABC');\n\nvm.editAll('999', 'I32', '||100');\n\nvm.editAll('999', 'I32', '1=10@ABC');\n\nvm.editAll('999', 'I32', '1=10//+4');\n\nvm.editAll('999', 'I32', '1.3,5@ABC//+4');"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-editall-adv')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-editall-adv')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_8")];
    [html appendString:@"<div class=\"card\">"];
    [html appendFormat:@"<div class=\"title-row\"><span class=\"tag blue\">IO</span><span class=\"title\">%@</span></div>", S("card_io_title")];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_io")];
    [html appendString:@"<div class=\"code-box\" id=\"code-io\">"];
    [html appendString:@"var value = vm.getValue('0x1000', 'I32');\nvm.log('Value: ' + value);\n\nvm.setValue('0x1000', '999', 'I32');\n\nvar floatVal = vm.getValue('0x2000', 'F32');\n\nvm.setValue('0x2000', '3.14', 'F32');"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-io')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-io')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_9")];
    [html appendString:@"<div class=\"card\">"];
    [html appendFormat:@"<div class=\"title-row\"><span class=\"tag green\">INFO</span><span class=\"title\">%@</span></div>", S("card_module_title")];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_module")];
    [html appendString:@"<div class=\"code-box\" id=\"code-mod\">"];
    [html appendString:@"var list = vm.getRangesList(0);\nfor (var i = 0; i < list.length; i++) {\n    vm.log('Module: ' + list[i].name);\n    vm.log('  Start: ' + list[i].start);\n    vm.log('  Size: ' + list[i].size);\n}\n\nvar filtered = vm.getRangesList('UnityFramework');\n\nvm.setBaseAddress('0x100000000');"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-mod')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-mod')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_10")];
    [html appendString:@"<div class=\"card\">"];
    [html appendFormat:@"<div class=\"title-row\"><span class=\"tag purple\">SYS</span><span class=\"title\">%@</span></div>", S("card_sys_title")];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_system")];
    [html appendString:@"<div class=\"code-box\" id=\"code-sys\">"];
    [html appendString:@"vm.sleep(1.0);\n\nvm.log('This is a log message');\n\nvm.toast('Operation complete!');\n\nvm.setFloatTolerance(2.0);"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-sys')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-sys')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_11")];
    [html appendString:@"<div class=\"card\">"];
    [html appendFormat:@"<div class=\"title-row\"><span class=\"tag orange\">LOCK</span><span class=\"title\">%@</span></div>", S("card_lock_title")];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_lock")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th></tr>", S("th_param"), S("th_desc")];
    [html appendFormat:@"<tr><td><code>value</code></td><td>%@</td></tr>", S("param_lock_value")];
    [html appendFormat:@"<tr><td><code>type</code></td><td>%@</td></tr>", S("param_type")];
    [html appendFormat:@"<tr><td><code>index/filter</code></td><td>%@</td></tr></table>", S("param_index_filter")];
    [html appendString:@"<div class=\"code-box\" id=\"code-lock\">"];
    [html appendString:@"vm.search('100', 'I32');\nvm.lock('9999', 'I32', 0);\nvm.lock('9999', 'I32', 1);\n\nvm.lockAll('9999', 'I32');\n\nvm.lockAll('9999', 'I32', '1=10');\nvm.lockAll('9999', 'I32', '@ABC');\n\n"];
    [html appendFormat:@"%@\n", S("comment_lock_offset")];
    [html appendString:@"vm.lockAll('9999', 'I32', '6//+0x8');\nvm.lockAll('9999', 'I32', '1=10//+0x28');\n\nvm.unlock(0);\nvm.unlockAll();"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-lock')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-lock')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_12")];
    [html appendString:@"<div class=\"card\">"];
    [html appendFormat:@"<div class=\"title-row\"><span class=\"tag purple\">PTR</span><span class=\"title\">%@</span></div>", S("card_pointer_title")];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_pointer")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th></tr>", S("th_param"), S("th_desc")];
    [html appendFormat:@"<tr><td><code>moduleName</code></td><td>%@</td></tr>", S("param_pointer_module")];
    [html appendFormat:@"<tr><td><code>baseOffset</code></td><td>%@</td></tr>", S("param_pointer_base")];
    [html appendFormat:@"<tr><td><code>offsets</code></td><td>%@</td></tr>", S("param_pointer_offsets")];
    [html appendFormat:@"<tr><td><code>type</code></td><td>%@</td></tr></table>", S("param_type")];
    [html appendString:@"<div class=\"code-box\" id=\"code-pointer\">"];
    [html appendString:@"// Read value via pointer chain\nvar result = vm.resolvePointer('UnityFramework', '0x1234', [0x10, 0x20, 0x8], 'I32');\nif (result.success) {\n    vm.log('Address: ' + result.address + ' Value: ' + result.value);\n}\n\n// Write value via pointer chain\nvm.writePointer('UnityFramework', '0x1234', [0x10, 0x20, 0x8], '9999', 'I32');\n\n// Lock value via pointer chain\nvm.lockPointer('UnityFramework', '0x1234', [0x10, 0x20, 0x8], '9999', 'I32', 'HP Lock');"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-pointer')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-pointer')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@ <span style=\"font-size:12px;color:#ff9f0a;background:rgba(255,159,10,0.15);padding:2px 8px;border-radius:5px;font-weight:bold;\">%@</span></div>", S("section_13"), S("rva_jb_tag")];
    [html appendString:@"<div class=\"card\">"];
    [html appendFormat:@"<div class=\"title-row\"><span class=\"tag blue\">RVA</span><span class=\"title\">%@</span><span class=\"tag orange\">%@</span></div>", S("card_rva_title"), S("rva_jb_tag")];
    [html appendFormat:@"<div class=\"scenario\">%@%@</div>", S("rva_jb_warning"), S("desc_rva")];
    [html appendFormat:@"<table class=\"param-table\"><tr><th>%@</th><th>%@</th></tr>", S("th_param"), S("th_desc")];
    [html appendFormat:@"<tr><td><code>moduleName</code></td><td>%@</td></tr>", S("param_rva_module")];
    [html appendFormat:@"<tr><td><code>offset</code></td><td>%@</td></tr>", S("param_rva_offset")];
    [html appendFormat:@"<tr><td><code>patchHex</code></td><td>%@</td></tr></table>", S("param_rva_hex")];
    [html appendString:@"<div class=\"code-box\" id=\"code-rva\">"];
    [html appendString:@"// Patch bytes at module+offset\nvm.patchRVA('UnityFramework', '0x1234', 'E0031F2A');\n\n// Restore original bytes\nvm.restoreRVA('UnityFramework', '0x1234', 'E0031FAA');\n\n// Read bytes at module+offset\nvar hex = vm.readRVA('UnityFramework', '0x1234', 4);\nvm.log('Bytes: ' + hex);"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-rva')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-rva')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendFormat:@"<div class=\"section-title\">%@</div>", S("section_demo")];
    [html appendString:@"<div class=\"card\">"];
    [html appendFormat:@"<div class=\"title-row\"><span class=\"tag orange\">DEMO</span><span class=\"title\">%@</span></div>", S("card_demo_title")];
    [html appendFormat:@"<div class=\"scenario\">%@</div>", S("desc_demo")];
    [html appendString:@"<div class=\"code-box\" id=\"code-demo\">"];
    [html appendString:@"vm.clear();\nvm.setFloatTolerance(1.0);\n\nvm.search('100', 'I32');\nvar count = vm.getResultsCount();\nvm.log('First search: ' + count);\n\nif (count > 100) {\n    vm.sleep(2.0);\n    vm.refine('100', 'I32', 'eq');\n    count = vm.getResultsCount();\n    vm.log('After refine: ' + count);\n}\n\nif (count > 0 && count < 50) {\n    vm.editAll('9999', 'I32');\n    vm.toast('Done!');\n}"];
    [html appendString:@"</div>"];
    [html appendFormat:@"<div class=\"btn-group\"><button class=\"btn btn-copy\" onclick=\"doCopy('code-demo')\">%@</button><button class=\"btn btn-insert\" onclick=\"doInsert('code-demo')\">%@</button></div>", S("btn_copy"), S("btn_insert")];
    [html appendString:@"</div>"];
    
    [html appendString:@"<script>"
     "function doCopy(id) {"
     "    var content = document.getElementById(id).innerText;"
     "    window.webkit.messageHandlers.vmHandler.postMessage({"
     "        action: 'copy', content: content"
     "    });"
     "}"
     "function doInsert(id) {"
     "    var content = document.getElementById(id).innerText;"
     "    window.webkit.messageHandlers.vmHandler.postMessage({"
     "        action: 'insert', content: content"
     "    });"
     "}"
     "</script>"];
    
    [html appendString:@"</body></html>"];
    
    #undef S
    
    return html;
}

static inline NSString* VMGenerateScriptGuideHTMLComplete() {
    std::string lang = VMGetCurrentLangCode();
    NSMutableString *html = (NSMutableString *)VMGenerateScriptGuideHTML();
    return VMGenerateScriptGuideHTML_Part2(html, lang);
}

#endif /* VMScriptGuideGenerator_h */
