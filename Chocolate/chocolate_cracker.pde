import controlP5.*;


int xNumber=5;//horizontal choco number
int yNumber=3;//virtical choco number
int Number=15;//all choco number
Choco[] chocos=new Choco[100];
int wchoco=60;//width of choco
int hchoco=40;//height of choco
int xmin=0;int ymin=0;
int xmax=0;int ymax=0;
int linemode=0;//if linemode==1 xline virtical,if linemode==2 yline horizon
int xline=0;
int yline=0;
int gamemode=1;//gamemode==0 is finish
int turnplayer=0;//0 is player,1 is  AI
int count=0;//for delay

ControlP5 Button1,Button2;
int redcolor;
color C1;

void setup()
{
  size(800,600);
  choconew();
  buttonnew();
}

void draw(){
  fadeToBlack();
  chocodraw();
  linedraw();
  GameFinish();
  AImove();
  count++;
}

void mouseClicked(MouseEvent e)
{
  if(turnplayer==0){
 if(linemode==0){ linecrick();}
 else {chococrack();turnplayer=1;count=0;}
  }
}


void choconew()
{
 for(int i=1;i<=Number;i++)
  {
    int ix=(int)(i-1) % xNumber;
    int iy=(int)(i-1) / xNumber;
    chocos[i]=new Choco(ix*wchoco+200,iy*hchoco+200,wchoco,hchoco);
  }
  xmin=chocos[1].x;ymin=chocos[1].y;
  xmax=chocos[xNumber].x+wchoco;ymax=chocos[Number].y+hchoco;
}

void chocodraw()
{
  for(int i=1;i<=Number;i++){
   if(chocos[i].activity==1)
   {
    chocos[i].draw();
   }
  }
}



class Choco//a piece of chocolate 
{
  int x,y;//(x,y)
  int w,h;//w*h
  int activity=1;//if activity==0,not active
  
  Choco(int _x,int _y,int _w,int _h)
  {
    x=_x;y=_y;
    w=_w;h=_h;
  }
  
  void draw()
  {
    fill(80,56,48);
    stroke(255,255,255);
    rect(x,y,w,h);
    rect(x+0.1*w,y+0.1*h,0.8*w,0.8*h);
  }
    
}

//screen renew
void fadeToBlack() {
  noStroke();
  fill(0, 60);
  rectMode(CORNER);
  rect(0, 0, width, height);
}

//line locate 
void linecrick()
{
  if(linemode==0&&(((xmin+0.1*wchoco<mouseX)&&(mouseX<xmax-0.1*wchoco)))&&(ymin+0.1*hchoco<mouseY)&&(mouseY<ymax-0.1*hchoco))
  {
    int a=(mouseX-xmin)%wchoco;int b=(mouseY-ymin)%hchoco;
    if((a<0.1*wchoco||0.9*wchoco<a)&&(0.1*hchoco<=b&&b<=0.9*hchoco))
    {
      linemode=1;
     if(a<0.1*wchoco){xline=mouseX-a;}
     else{xline=mouseX-a+wchoco;}
    }
    if((0.1*wchoco<=a&&a<=0.9*wchoco)&&(b<0.1*hchoco||0.9*hchoco<b))
    {
      linemode=2;
      if(b<0.1*hchoco){yline=mouseY-b;}
      else{yline=mouseY-b+hchoco;}
    }
  }
}

void linedraw()
{
  if(linemode==1){line(xline,max(0,ymin-2*hchoco),xline,min(height,ymax+2*hchoco));}
  if(linemode==2){line(max(0,xmin-2*wchoco),yline,min(width,xmax+2*wchoco),yline);}
}

void chococrack()
{
  if(linemode==1)
    {
      if(mouseX<xline){for(int i=1;i<=Number;i++){if(chocos[i].x<xline){chocos[i].activity=0;}}linemode=0;xmin=xline;xline=0;}
      else if(mouseX>xline){for(int i=1;i<=Number;i++){if(chocos[i].x>=xline){chocos[i].activity=0;}}linemode=0;xmax=xline;xline=0;}
    }
  else if(linemode==2)
    {
        if(mouseY<yline){for(int i=1;i<=Number;i++){if(chocos[i].y<yline){chocos[i].activity=0;}}linemode=0;ymin=yline;yline=0;}
        else if(mouseY>yline){for(int i=1;i<=Number;i++){if(chocos[i].y>=yline){chocos[i].activity=0;}}linemode=0;ymax=yline;yline=0;}
    }
}

void chococrackAI()
{
 int x=(xmax-xmin)/wchoco;
 int y=(ymax-ymin)/hchoco;
 if(x>y){xline=xmin+(x-y)*wchoco;for(int i=1;i<=Number;i++){if(chocos[i].x<xline){chocos[i].activity=0;}};xmin=xline;xline=0;}
 else if(y>x){yline=ymin+(y-x)*hchoco;for(int i=1;i<=Number;i++){if(chocos[i].y<yline){chocos[i].activity=0;}};ymin=yline;yline=0;}
 else if(y==x){xline=xmin+wchoco;for(int i=1;i<=Number;i++){if(chocos[i].x<xline){chocos[i].activity=0;}};xmin=xline;xline=0;}
}

void AImove()
{
  if(turnplayer==1&&gamemode==1)
  {
         fill(255);

       textSize(24);

       float x=width/2f;
       float y=60;
       text("AI turn",x,y);
    if(count>100)
    {
    chococrackAI();
    turnplayer=0;
    }
  }
}

void GameFinish()
{
  if(xmax==xmin+wchoco&&ymax==ymin+hchoco)
  {
       gamemode=0;
           fill(255);

       textSize(24);
       textAlign(CENTER,CENTER);

       float x=width/2f;
       float y=height/2f;
       text("Game Finish.",x,y);
       if(turnplayer==0){text("You Lose",x,y+50);}
       else{text("You Win!!",x,y+50);}
  }
}

void buttonnew()
{

  C1 = redcolor = color(255, 0, 0);

  Button1 = new ControlP5(this);
  Button1.addButton("reset")
    .setLabel("Reset_Button")
    .setPosition(50, 40)
    .setSize(100, 40)
    .setColorCaptionLabel(redcolor); 
    
  Button2 = new ControlP5(this);
  Button2.addButton("renew")
    .setLabel("Renew_Button")
    .setPosition(180, 40)
    .setSize(100, 40)
    .setColorCaptionLabel(redcolor); 
    
}


void reset() 
{
  gamemode=1;
  linemode=0;
  xmin=0;ymin=0;xmax=0;ymax=0;
  xline=0;yline=0;
  choconew();
  linemode=0;
  turnplayer=0;
  count=0;
}

void renew() 
{
  gamemode=1;
  linemode=0;
  xmin=0;ymin=0;xmax=0;ymax=0;
  xline=0;yline=0;
  xNumber=(int)random(5,8);
  yNumber=(int)random(3,6);
  Number=xNumber*yNumber;
  choconew();
  linemode=0;
  turnplayer=0;
  count=0;
}
