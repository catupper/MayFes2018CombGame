class Board{
  int [][] field;
  int n, m;
  int grid_size;
  int turn;
  int left, top;
  int lastx, lasty;
  Board(int _n, int _m, int _l, int _t){
    n = _n;
    m = _m;
    left = _l;
    top = _t;
    grid_size = 40;
    lastx = -1;
    lasty = -1;
    field = new int[n][m];
    for(int i = 0;i < n;i++){
      for(int j = 0;j < m;j++){
        field[i][j] = 1;
      }
    }
    turn = 0;
  }
  
  void draw_grid(int left, int top, int cond){
    if(cond == 0)return;
    if(cond == 1){
      stroke(0,0,0);
      noFill();
      rect(left, top, grid_size, grid_size);
    }
    if(cond == 2){
      stroke(150,150,150);
      fill(150, 150, 150);
      rect(left, top, grid_size, grid_size);  
    }
  }
  
  void drawField(){
    fill(0,0,0);
    ellipse(left + grid_size / 2, top + grid_size / 2, grid_size, grid_size);
    for(int i = 0;i < n;i++){
      for(int j = 0;j < m;j++){
        draw_grid(left + i * grid_size, top + j * grid_size, field[i][j]);
      }
    }
    if(lastx != -1){
      if(turn == 0)fill(255, 0, 0);
      if(turn == 1)fill(0, 0, 255);
      ellipse(left + lastx * grid_size + grid_size / 2, top + lasty * grid_size + grid_size / 2, grid_size, grid_size);
    }
    
  }
  
  void hover(int x, int y){
    x = (x-left) / grid_size;
    y = (y-left) / grid_size;
    for(int i = 0;i < n;i++){
      for(int j = 0;j < m;j++){
        if(field[i][j] > 0){
          field[i][j] = 1;
        }
      }
    }
    if(x < 0 || n <= x || y < 0 || m <= y)return;
    if(field[x][y] == 0)return;
    for(int i = x;i < n;i++){
      for(int j = y;j < m;j++){
        if(field[i][j] > 0)field[i][j] = 2;
      }
    }
  }
  
  int _select(int x, int y){
    if(x < 0 || n <= x || y < 0 || m <= y)return 0;
    if(field[x][y] == 0)return 0;
    for(int i = x;i < n;i++){
      for(int j = y;j < m;j++){
        field[i][j] = 0;
      }
    }
    lastx = x;
    lasty = y;
    return 1;
  }
  
  int select(int x, int y){
    x = (x-left) / grid_size;
    y = (y-left) / grid_size;
    return _select(x, y);
  }
  
  int check_game_over(){
    if(field[0][0] == 0)return 1;
    else return 0;    
  }
  
  void change_turn(){
    turn ^= 1;
  }
  
  void draw_turn(){
    if(turn == 0){
      fill(0,0,0);
      textSize(50);
      text("Your Turn!", 80, 80);
    }
    else{
      fill(0,0,0);
      textSize(50);
      text("PC Turn!", 80, 80);
    }
    if(lastx != -1){
      fill(255, 0, 0);
      text("last move:(" + lastx + ", " + lasty + ")", 500, 80);
    }
  }

  void game_over(){
    fill(0,0,0);
    textSize(50);
    if(turn == 0){
      text("PC Win!", 80, 80);
    }
    if(turn == 1){
      text("You Win!", 80, 80);
    }
    drawField();
    text("Press Any Key", 80, 500);
  }
  
  void reset(){
    lastx = -1;
    lasty = -1;
    for(int i = 0;i < n;i++){
      for(int j = 0;j < m;j++){
        field[i][j] = 1;
      }
    }
    turn = 0; 
  }
  
  int[][] tryboard(int x, int y){
    int[][] newfield = new int[n][m];
    for(int i = 0;i < n;i++){
      for(int j = 0;j < m;j++){
        if(field[i][j] == 0)newfield[i][j] = 0;
        else newfield[i][j] = 1;
      }
    }
    for(int i = x;i < n;i++){
      for(int j = y;j < m;j++){
        newfield[i][j] = 0;
      }
    }
    return newfield;
  }
  
  int symmetry(int[][] field){
    int x = min(n, m);
    for(int i = 0;i < n;i++){
      for(int j = 0;j < m;j++){
        if(i >= x || j >= x){
          if(field[i][j] == 1)return 0;
          continue;
        }
        if(field[i][j] != field[j][i])return 0;
      }
    }
    return 1;
  }
  
  void AI(){
    int cnt = 0;
    for(int i = 0;i < n;i++){
      for(int j = 0;j < m;j++){
        if(field[i][j] > 0)cnt++;
      }
    }
    int x = 0, y = 0;
    for(int i = 0;i < n;i++){
      for(int j = 0;j < m;j++){
        if(field[i][j] == 0)continue;
        int[][] newfield = tryboard(i, j);
        if(symmetry(newfield) == 1){
          x = i;
          y = j;
        }
      }
    }
    int rand = int(random(cnt));
    if(x == 0 && y == 0){
      for(int i = 0;i < n;i++){
        for(int j = 0;j < m;j++){
          if(field[i][j] == 0)continue;
          rand--;
          if(rand == 0){
            x = i;
            y = j;
          }
        }
      }
    }
    _select(x,y);
  }
  
  
  void AI2(){
    int val = convertToVal(decreaseDim(field)); 
    find(val);
    int x = dpx[val];
    int y = dpy[val];
    if(x == -1){
      int cnt = 0;
      for(int i = 0;i < 10;i++){
        for(int j = 0;j < 12;j++){
          if(field[i][j] > 0)cnt++;
        }
      }
      if(cnt == 1){
        x = 0;
        y = 0;
      }
      int hoge = (int)random(cnt-1) + 1;
      for(int i = 0;i < 10;i++){
        for(int j = 0;j < 12;j++){
          if(field[i][j] == 0)continue;
          if(hoge-- == 0){
            x = i;
            y = j;
          }
        }
      }
    }
    _select(x,y);
  }
}

Board game;
