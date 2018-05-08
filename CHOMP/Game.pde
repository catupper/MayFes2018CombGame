class Board{
  int [][] field;
  int n, m;
  int grid_size;
  int turn;
  int left, top;  
  Board(int _n, int _m, int _l, int _t){
    n = _n;
    m = _m;
    left = _l;
    top = _t;
    grid_size = 30;
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
    ellipse(left + grid_size / 2, top + grid_size / 2, grid_size, grid_size);
    for(int i = 0;i < n;i++){
      for(int j = 0;j < m;j++){
        draw_grid(left + i * grid_size, top + j * grid_size, field[i][j]);
      }
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
  
  int select(int x, int y){
    x = (x-left) / grid_size;
    y = (y-left) / grid_size;
    if(x < 0 || n <= x || y < 0 || m <= y)return 0;
    if(field[x][y] == 0)return 0;
    for(int i = x;i < n;i++){
      for(int j = y;j < m;j++){
        field[i][j] = 0;
      }
    }
    return 1;
  }
  
  int check_game_over(){
    if(field[0][0] == 0)return 1;
    else return 0;    
  }
  
  void change_turn(){
    turn ^= 1;
  }
  
  void draw_turn(){
    println(turn);
    if(turn == 0){
      fill(0,0,0);
      textSize(50);
      text("Your Turn!", 80, 80);
    }
    else{
      fill(0,0,0);
      textSize(50);
      text("My Turn!", 80, 80);
    }
  }

  void game_over(){
    fill(0,0,0);
    textSize(50);
    if(turn == 0){
      text("I Win!", 80, 80);
    }
    if(turn == 1){
      text("You Win!", 80, 80);
    }
  }
  
  void reset(){
    for(int i = 0;i < n;i++){
      for(int j = 0;j < m;j++){
        field[i][j] = 1;
      }
    }
  }
}

Board game;