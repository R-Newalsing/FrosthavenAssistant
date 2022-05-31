class MonsterModel {
  MonsterModel(this.name, this.display, this.gfx, this.hidden,
    this.deck,
    this.count,
      this.levels
      );
  final String name; //id
  final String deck;
  final String display; //same as name. most of the time
  final String gfx; //same as name. most of the time
  final bool hidden;
  final int count;
  final List<MonsterLevelModel> levels;

  factory MonsterModel.fromJson(Map<String, dynamic> data) {
    // note the explicit cast to String
    // this is required if robust lint rules are enabled
    final name = data['name'] as String;
    String display = name;
    if(data.containsKey('display')){
      display = data['display'] as String;
    }
    String gfx = display;
    if(data.containsKey('gfx')){
      gfx = data['gfx'] as String;
    }
    bool hidden = false;
    if(data.containsKey('hidden')){
      hidden = data['hidden'] as bool;
    }
    final deck = data['deck'] as String;
    final count = data['count'] as int;

    //final levels = data['levels'] as List<MonsterLevelData>;
    final levels = data['levels'] as List<dynamic>;
    List<MonsterLevelModel> monsterLevelDataList = [];
    for (var item in levels) {
      monsterLevelDataList.add(MonsterLevelModel.fromJson(item));
    }
    return MonsterModel(name, display, gfx, hidden, deck, count, monsterLevelDataList);
  }
}

class MonsterLevelModel {
  MonsterLevelModel(this.level, this.normal, this.elite, this.boss);
  final int level;
  MonsterStatsModel? normal;
  MonsterStatsModel? elite;
  MonsterStatsModel? boss;

  factory MonsterLevelModel.fromJson(Map<String, dynamic> data) {
    // note the explicit cast to String
    // this is required if robust lint rules are enabled
    final level = data['level'] as int;
    MonsterStatsModel normal;
    MonsterStatsModel elite;
    if(data.containsKey('normal') && data.containsKey('elite')) {
      normal = MonsterStatsModel.fromJson(data['normal']);
      elite = MonsterStatsModel.fromJson(data['elite']);
      return MonsterLevelModel(level, normal, elite, null);
    } else {
      //boss
      //could change the json though...
      return MonsterLevelModel(level, null, null, MonsterStatsModel.fromJson(data));
    }
  }
}

class MonsterStatsModel {
  MonsterStatsModel(this.health, this.move, this.attack, this.range, this.attributes, this.immunities, this.special1, this.special2);
  final dynamic health; //or string
  final int move;
  final dynamic attack;
  final int range;
  final List<String> attributes;
  final List<String> immunities;
  final List<String> special1;
  final List<String> special2;

  factory MonsterStatsModel.fromJson(Map<String, dynamic> data) {
    // note the explicit cast to String
    // this is required if robust lint rules are enabled
    final health = data['health'];
    final move = data['move'] as int;
    final attack = data['attack'];
    int range = 0;
    if(data.containsKey('range')) {
      range = data['range'] as int;
    }
    List<String> attributes = [];
    if(data.containsKey('attributes')) {
      attributes = (data['attributes'] as List<dynamic>).cast<String>();
    }
    List<String> immunities = [];
    if(data.containsKey('immunities')) {
      immunities = (data['immunities'] as List<dynamic>).cast<String>();
    }
    List<String> special1 = [];
    if(data.containsKey('special1')) {
      special1 = (data['special1'] as List<dynamic>).cast<String>();
    }
    List<String> special2 = [];
    if(data.containsKey('special2')) {
      special2 = (data['special2'] as List<dynamic>).cast<String>();
    }
    return MonsterStatsModel(health, move, attack, range, attributes, immunities, special1, special2);
  }
}

/*
"edition": "JotL",
      "deck": "Basic Giant Viper",
      "hidden": true,
      "count": 10,
      "levels": [
        {
          "level": 0,
          "normal": {
            "health": 2,
            "move": 2,
            "attack": 1,
            "attributes": [ "%poison%" ]
          },
          "elite": {
            "health": 3,
            "move": 2,
            "attack": 2,
            "attributes": [ "%poison%" ]
          }
        },
 */