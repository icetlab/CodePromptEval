
tot_success=0
ic=0
zzz=0
dictt_not_project={}
dict_std_nonestd={"/home/travis/builds/repos/standalone/neo4j-_meta-deprecated.py":"/home/travis/builds/repos/neo4j---neo4j-python-driver/src/neo4j/_meta_deprecated_passk_validte.py",
                  "/home/travis/builds/repos/standalone/neo4j-work-query-unit_of_work.py":"/home/travis/builds/repos/neo4j---neo4j-python-driver/src/neo4j/_work/query_unit_of_work_passk_validte.py",
                  "/home/travis/builds/repos/standalone/krake-krake-controller-kubernetes-hooks-on.py":"/home/travis/builds/repos/rak-n-rok---Krake/krake/krake/controller/kubernetes/hooks_on_passk_validte.py"}
f_map=open("record_testcases_map_python.json",'w',encoding="utf-8")
dictt_testcases_map={}
if __name__ == "__main__":
    c=0
    import sys
    import json

    f = open("testcasesoriginal", 'r', encoding="utf-8")
    content = f.read()
    f.close()
    content_list = content.split("----------------------------")
    dictt = {}
    for i in range(1, len(content_list)):
        temp_content = content_list[i]
        temp_content_list = temp_content.split("\n")
        _id = temp_content_list[1]
        test_content = ""
        for j in range(2, len(temp_content_list)):
            test_content += temp_content_list[j]
            test_content += "\n"
        dictt[_id] = test_content

    # print(dictt)
    # print(len(dictt))
    f = open("CoderEval4Python.json", 'r', encoding="utf-8")
    content = f.read()
    f.close()

    import os
    import json, dill

    content_json = json.loads(content)
    listtot = []
    dictt_origin = {}
    project_dir = "/home/travis/builds/repos"
    for l in content_json['RECORDS']:
        dictt_origin[l["_id"]] = l

    zz = 0
    list_stadnalone_id = []
    for keyy in dictt.keys():
        if dictt[keyy].find("/home/travis/builds/repos/") < 0:
            # zz+=1
            # print("----------------------")
            # print(dictt[keyy])
            if dictt[keyy].find("def ") >= 0:
                list_stadnalone_id.append(keyy)
                zz += 1
    kk = 0
    project_path = "/home/travis/builds/repos/"
    for keyy in dictt_origin:
        dictTemp = dictt_origin[keyy]
        if keyy in list_stadnalone_id:
            save_data = project_path + "standalone/" + dictTemp["file_path"].replace(".py", "").replace("/",

                                                                                                        "-") + "-" + \
                        dictTemp["name"] + ".py"
        else:
            file_path = dictTemp['file_path']
            if project_path + dictTemp["project"].replace("/",
                                                          "---") == "/home/travis/builds/repos/neo4j---neo4j-python-driver":
                save_data = os.path.join(project_path + dictTemp['project'].replace("/", "---") + "/src",
                                         file_path).replace(
                    ".py", "_" + dictTemp["name"] + "_passk_validte.py")
            else:
                save_data = os.path.join(project_path + dictTemp['project'].replace("/", "---"), file_path).replace(
                    ".py", "_" + dictTemp["name"] + "_passk_validte.py")
            if save_data.find("/home/travis/builds/repos/mozilla---relman-auto-nag") >= 0:
                save_data = save_data.replace("/home/travis/builds/repos/mozilla---relman-auto-nag/auto-ang",
                                              "/home/travis/builds/repos/mozilla---relman-auto-nag/bugbot")

            templ = save_data.split("/")
            if not os.path.exists(save_data):
                print("notexis!!")
                print(save_data)
                continue
        if save_data in dict_std_nonestd.keys():
            save_data=dict_std_nonestd[save_data]
        try:
            fread=open(save_data,'r',encoding="utf-8")
            content_temp=fread.read()
            fread.close()
            dictt_testcases_map[keyy]=content_temp

        except:

            continue
    f_map.write(json.dumps(dictt_testcases_map))
    f_map.close()

