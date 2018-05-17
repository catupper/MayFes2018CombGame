import java.util.*;

/* TODO:
 * 終了判定
 *
 * 判定がシビア && コーナーケースが多い
 * 新しく作った線分が元ある曲線にぶつかったらどうするの
 */

static class Constant {
	static final int initialDepthVertex = 10000;
	static final int initialDepthCurve = 0;
	static final int initialDepthCurveActive = 1000;
	static final int initialDepthCollision = 100000;
}

static int colorRef(int r, int g, int b, int a) {
	if (r < 0 || r >= 256) throw new IllegalArgumentException();
	if (g < 0 || g >= 256) throw new IllegalArgumentException();
	if (b < 0 || b >= 256) throw new IllegalArgumentException();
	if (a < 0 || a >= 256) throw new IllegalArgumentException();
	return (a << 24) | (r << 16) | (g << 8) | b;
}

static int colorRef(int r, int g, int b) {
	return colorRef(r, g, b, 255);
}


/*-----------------------------*/
/*-----   TimerForCurve   -----*/
/*-----------------------------*/

/* 曲線を一定の長さ引くごとにそれを教えてくれるクラス */
static class TimerForCurve {
	final float interval;		// 距離間隔
	double sumDistance;			// これが interval 以上になると知らせる
	Vector2D prevPosition;		// 前フレームにおける位置

	TimerForCurve(Vector2D start, float interval_) {
		interval = interval_;
		prevPosition = start;
		sumDistance = 0;
	}

	/* 毎フレーム呼び出す, 前フレームにおける位置からの距離を加算する */
	void update(Vector2D position) {
		sumDistance += prevPosition.sub(position).norm();
		prevPosition = position;
	}

	/* 一定の長さ以上になっていたら true */
	boolean elapsed() {
		boolean elapsed_ = false;
		while (sumDistance >= interval) {	 // interval の2倍以上になっていたとしても知らせるのは一度
			sumDistance -= interval;
			elapsed_ = true;
		}
		return elapsed_;
	}
}

/*-----------------------------*/
/*------   Displayable   ------*/
/*-----------------------------*/

/* 描画したいオブジェクトの基底クラス */
static interface Displayable {
	void display();
}

/*-----------------------------*/
/*-------   Displayer   -------*/
/*-----------------------------*/

/* 追加された Displayable オブジェクトを描画する */
static class Displayer {
	static Map<Displayable, Integer> objectToDepth
		= new HashMap<Displayable, Integer>();			// オブジェクト値から深度を割り出す
	static Map<Integer, List<Displayable>> map
		= new TreeMap<Integer, List<Displayable>>();	// オブジェクトを深度ごとに格納する(深度は大きいほうが手前)

	static void update() {
		for (Map.Entry<Integer, List<Displayable>> entry : map.entrySet()) {
			for (Displayable object : entry.getValue()) {
				object.display();
			}
		}
	}

	/* オブジェクトを描画リストに追加(深度はできるだけ重複しないほうが良い) */
	static void add(Displayable object, int depth) {
		objectToDepth.put(object, depth);	// オブジェクトと深度を対応付ける
		if (map.get(depth) == null) {		// その深度のリストがなければ作成
			map.put(depth, new ArrayList<Displayable>());
		}
		map.get(depth).add(object);			// 追加
	}

	/* オブジェクトを描画リストから削除 */
	static void remove(Displayable object) {
		Integer depth = objectToDepth.get(object);	// そのオブジェクトの深度を取得
		if (depth == null) return;

		objectToDepth.remove(object);				// リストから削除(深度との対応付けも消去)
		map.get(depth).remove(object);
	}
}

/*-----------------------------*/
/*-----   DrawingTools   ------*/
/*-----------------------------*/

/* 描画する際にはこれらの関数を使うこと; static class になっていないのは processing の制限による */
class DrawingTools {
	/* 線分を描く */
	void drawLine(Segment segment, color col) {
		final int weight = 3;
		strokeWeight(weight);
		stroke(col);

		Vector2D from = segment.start();
		Vector2D to = segment.end();
		line(from.x(), from.y(), to.x(), to.y());
	}

	void drawLine(Segment segment) {
   		drawLine(segment, colorRef(0, 0, 0));
	}

	void drawLineForDebug(Segment segment) {
		strokeWeight(1);
		Vector2D from = segment.start();
		Vector2D to = segment.end();
		line(from.x(), from.y(), to.x(), to.y());
	}

	/* 円を描く */
	void drawCircle(Vector2D position, float radius, color col) {
		fill(col);
		noStroke();
		ellipse(position.x(), position.y(), radius * 2, radius * 2);
	}

	void drawCircle(Vector2D position, float radius) {
	   	drawCircle(position, radius, colorRef(0, 0, 0));
	}
}

/*-----------------------------*/
/*--------   Vertex   ---------*/
/*-----------------------------*/

static final int degreeMax = 1;		// 1頂点から伸ばせる線の最大数

/* 頂点の状態 */
static enum VertexState {
	Locked,		// 次数最大
	Unlocked,	// 次数にまだ余裕がある(かつマウスが乗っていない)
	MouseOver	// 次数にまだ余裕があり、マウスが乗っている
};

/* 線をつなぐための頂点 */
class Vertex implements Displayable {
	final int radius = 14;		// 円の半径(描画用)
	Vector2D position;			// 中心位置
	int degree;					// 現在この頂点から伸びている線の本数(次数)
	VertexState state = VertexState.Unlocked;	// 状態

	Vertex(Vector2D position_) {
		position = position_;
	}

	/* 毎フレーム更新 */
	void update() {
		if (isLocked()) {
			state = VertexState.Locked;
		} else {
			if (mouseIsOver()) {
				state = VertexState.MouseOver;
			} else {
				state = VertexState.Unlocked;
			}
		}
	}

	Vector2D getPosition() {
		return position;
	}

	void display() {
		final color mouseOverColor = colorRef(112, 112, 255);	// 次数が限界に達していない頂点のマウスオーバー時の色

		switch (state) {
		case MouseOver:
			drawingTools.drawCircle(position, radius, mouseOverColor);
			break;
		}
	}

	/* 次数の増加を外部から知らせるためのメソッド */
	void connect() {
		if (degree >= degreeMax) throw new IllegalStateException();
		++degree;
	}

	/* 次数の減少を外部から知らせるためのメソッド */
	void disconnect() {
		if (degree <= 0) throw new IllegalStateException();
		--degree;
	}

	/* 次数が上限に達しているか */
	boolean isLocked() {
		return degree >= degreeMax;
	}

	/* 点 point が頂点の上に(見た目上)存在するか */
	boolean includes(Vector2D point) {
		Vector2D diff = position.sub(point);
		return diff.norm2() <= radius * radius;
	}

	/* マウスが乗っているか */
	private boolean mouseIsOver() {
		Vector2D mousePosition = new Vector2D(mouseX, mouseY);
		return includes(mousePosition);
	}
}

/*-----------------------------*/
/*---------   Curve   ---------*/
/*-----------------------------*/

/* 固定化された曲線 */
class Curve implements Displayable, Iterable<Segment> {
	final List<Segment> segments;
	final color col;

	Curve(List<Segment> segments_, color col_) {
		for (int i = 1; i < segments_.size(); ++i) {
			if (segments_.get(i - 1).end() != segments_.get(i).start()) {
				throw new IllegalArgumentException();		//各線分は接続していなければならない
			}
		}

		segments = new ArrayList<Segment>(segments_);
		col = col_;
	}

	/* 折れ線のセグメント数 */
	int size() {
		return segments.size();
	}

	/* 曲線中央に位置する線分を取得(新しい頂点を作るための線分); */
	Segment getCenterSegment() {
		return segments.get(segments.size() / 2);
	}

	/* 曲線を2つに分割する(TODO: getCenterSegment とまとめる) */
	List<Curve> split() {
		int half = segments.size() / 2;
		Segment centerSegment = segments.get(half);				// 分割するべき線分
		Vector2D middlePoint = centerSegment.middlePoint();		// 分割点

		List<Segment> firstList = new ArrayList<Segment>(segments.subList(0, half));					// 線分リストの前半
		List<Segment> secondList = new ArrayList<Segment>(segments.subList(half + 1, segments.size()));	// 線分リストの後半
		firstList.add(new Segment(centerSegment.start(), middlePoint));			// 分割した線分の片割れを追加
		secondList.add(0, new Segment(middlePoint, centerSegment.end()));		// 前に追加することに注意

		/* 曲線を生成して返す */
		Curve first = new Curve(firstList, col);
		Curve second = new Curve(secondList, col);
		List<Curve> curves = new ArrayList<Curve>();
		curves.add(first);
		curves.add(second);
		return curves;
	}

	Iterator<Segment> iterator() {
		return segments.iterator();
	}

	void display() {
		for (Segment segment : segments) {
			drawingTools.drawLine(segment, col);
		}
	}
}

/*-----------------------------*/
/*------   CurveActive   ------*/
/*-----------------------------*/

/* 現在描いている途中の曲線 */
class CurveActive implements Displayable, Iterable<Segment> {
	List<Segment> segments = new ArrayList<Segment>();
	Vector2D last;					// 現在終点となっている座標
	boolean isUpdated = false;		// 線分が追加されたかどうか
	color col;

	CurveActive(Vector2D start, color col_) {
		last = start;
		col = col_;
	}

	Iterator<Segment> iterator() {
		return segments.iterator();
	}

	/* 曲線に点 point を追加する */
	void extend(Vector2D point) {
		Segment newSegment = new Segment(last, point);
		segments.add(newSegment);
		last = point;
		isUpdated = true;
	}

	/* 曲線を終端する(当たり判定の調整) */
	void terminate(Vector2D point) {
		extend(point);		// 累積距離にかかわらず追加する
	}

	boolean isUpdated(){
		if (isUpdated) {
			isUpdated = false;
			return true;
		}
		return false;
	}

	/* CurveActive を Curve に変換する(コード内ではこの意味で動詞 'solidify' を使うことにする) */
	Curve solidify(Vector2D end, color solidifiedCol) {
		return new Curve(segments, solidifiedCol);
	}

	Segment getLastSegment() {
		if (segments.size() == 0) return null;
		return segments.get(segments.size() - 1);
	}

	void display() {
		for (Segment segment : segments) {
			drawingTools.drawLine(segment, col);
		}
	}
}

/*-----------------------------*/
/*-------   FieldData   -------*/
/*-----------------------------*/

/* フィールド上のオブジェクトの集まり */
static class FieldData {
	List<Vertex> vertices = new ArrayList<Vertex>();	// 頂点の集合
	List<Curve> curves = new ArrayList<Curve>();		// 直線の集合
	CurveActive curveActive = null;							// 描き途中の曲線

	static int depthVertex = Constant.initialDepthVertex;
	static int depthCurve = Constant.initialDepthCurve;
	static int depthCurveActive = Constant.initialDepthCurveActive;

	/* 頂点を追加 */
	void addVertex(Vertex vertex) {
		vertices.add(vertex);
		Displayer.add(vertex, depthVertex);
		++depthVertex;
	}

	/* 曲線を追加 */
	void addCurve(Curve curve) {
		curves.add(curve);
		Displayer.add(curve, depthCurve);
		++depthCurve;
	}

	/* 描き途中の曲線をセット */
	void setCurveActive(CurveActive curveActive_) {
		curveActive = curveActive_;
		Displayer.add(curveActive, depthCurveActive);
	}

	/* 描き途中の曲線を削除 */
	void resetCurveActive() {
		Displayer.remove(curveActive);
		curveActive = null;
	}

	CurveActive getCurveActive() {
		return curveActive;
	}

	/* position に存在する頂点を(高々1つ)返す; なければ null を返す */
	Vertex fetchVertex(Vector2D position) {
		for (Vertex vertex : vertices) {
			if (vertex.isLocked()) continue;		// 次数限界の点は選ばない
			if (vertex.includes(position)) {
				return vertex;
			}
		}
		return null;
	}

	void update() {
		/* 各頂点を更新(頂点の色を変えるのに必要) */
		for (Vertex vertex : vertices) {
			vertex.update();
		}
	}

	/* 曲線を格納したコレクションを返す;
	   TODO: コレクションを丸ごと返すのは変なのだが、楽なので */
	List<Curve> getCurves() {
		return new ArrayList<Curve>(curves);
	}

	List<Vertex> getVertices() {
		return vertices;
	}
}

/*-----------------------------*/
/*-------   Collision   -------*/
/*-----------------------------*/

class Collision implements Displayable {
	Vector2D position;	// 衝突位置
	final int radius = 8;

	Collision(Vector2D position_) {
		position = position_;
	}

	void display() {
		final color col = colorRef(64, 192, 192);
		drawingTools.drawCircle(position, radius, col);
	}
}

/*-----------------------------*/
/*---   CollisionDetector   ---*/
/*-----------------------------*/

/* 線分の交差が起きている場所をすべて返すようなクラス */
/* TODO: 累計とフレーム差分の両方が返せるように工夫しよう(必要ないかも?) */
static int depthCollision = Constant.initialDepthCollision;
class CollisionDetector {
	final FieldData data;
	List<Collision> collisions = new ArrayList<Collision>();

	CollisionDetector(FieldData data_) {
		data = data_;
	}

	void update() {
		updateCollision();
	}

	/* 衝突を計算し, Collision の生成を行う  */
	private void updateCollision() {
		for (Vector2D point : getNewCollisionPoints()) {
			Collision collision = new Collision(point);
			collisions.add(collision);
			Displayer.add(collision, depthCollision);
			++depthCollision;
		}

		/* curveActive がなくなったら衝突点も消える */
		if (data.getCurveActive() == null) {
			for (Collision collision : collisions) {
				Displayer.remove(collision);
			}
			collisions.clear();
		}
	}

	/* (現フレームで)新たに増えた衝突点を取得する */
	private List<Vector2D> getNewCollisionPoints() {
		List<Vector2D> list = new ArrayList<Vector2D>();
		CurveActive curveActive = data.getCurveActive();

		if (curveActive == null) return list;
		if (!curveActive.isUpdated()) return list;			// curveActive が変化していないなら 衝突点も増えていない
		Segment subject = curveActive.getLastSegment();		// 最後に追加された辺だけを判定する

		/* curves との交差判定 */
		for (Curve curve : data.getCurves()) {
			for (Segment object : curve) {
				if (MathUtility.intersects(subject, object)) {
					Vector2D intersectionPoint = MathUtility.intersectionPoint(subject, object);
					list.add(intersectionPoint);
				}
			}
		}

		/* curveActive との交差判定 */
		for (Segment object : curveActive) {
			if (MathUtility.intersects(subject, object)) {
				Vector2D intersectionPoint = MathUtility.intersectionPoint(subject, object);
				list.add(intersectionPoint);
			}
		}

		return list;
	}

	/* 交差している点があるかどうか */
	boolean collisionExists() {
		updateCollision();
		return collisions.size() != 0;
	}
}

/*-----------------------------*/
/*---------   Judge   ---------*/
/*-----------------------------*/

/* ゲームの進行、プレイヤーが正しい操作をしているか判定 */
class Judge {
	final FieldData data;
	final CollisionDetector collisionDetector;
	final GameManager gameManager;		// コールバック用

	/* CurveActive に関する状態 */
	CurveActive curveActive = null;		// 描き途中の曲線
	Vertex startSelected = null;		// curveActive の始点
	Vertex endSelected = null;			// curveActive の終点

	final int markerMax = 2;					// マーカー数
	final int turnMax = 5 * markerMax - 2;		// このゲームが結局何ターンで終了してしまうか
	int turnCount = 0;							// 現在のターン数
	boolean turnEnded = false;					// ターンエンドのフラグ(update 内で用いる)

	Judge(GameManager gameManager_) {
		gameManager = gameManager_;

		/* GameManager に尋ね、必要なオブジェクトの参照を受け取る */
		data = gameManager.getFieldData();
		collisionDetector = gameManager.getCollisionDetector();

		initialize();
	}

	/*------ ゲーム開始前の準備 ------*/

	void initialize() {
		/* マーカーの作成 */
		List<Vector2D> markerPositions = decideMarkerPositions();
		locateMarkers(markerPositions);

		/* 枠の作成 */
		createOuterFrame();
	}

	/* 十字型マーカーの位置を決める */
	private List<Vector2D> decideMarkerPositions() {
		int windowWidth = width;
		int windowHeight = height;
		Vector2D center = new Vector2D(windowWidth / 2, windowHeight / 2);		// 中心
		Vector2D circle = new Vector2D(windowWidth / 4, windowHeight / 4);		// 楕円半径
		final int uncertainty = 30;		// ゆらぎ

		List<Vector2D> markerPositions = new ArrayList<Vector2D>();
		for (int i = 0; i < markerMax; ++i) {
			Vector2D diff = new Vector2D(
				(int)(circle.x() * cos(TWO_PI * i / markerMax - HALF_PI)),
				(int)(circle.y() * sin(TWO_PI * i / markerMax - HALF_PI))
			);
			Vector2D rand = new Vector2D(
				(int)random(-uncertainty, uncertainty),
				(int)random(-uncertainty, uncertainty)
			);

			Vector2D position = center.add(diff).add(rand);
			markerPositions.add(position);
		}
		return markerPositions;
	}

	/* 十字型マーカーをフィールドに配置する */
	private void locateMarkers(List<Vector2D> markerPositions) {
		final int radius = 30;		// マーカーの大きさ

		for (Vector2D markerPosition : markerPositions) {
			Vector2D left   = markerPosition.add(new Vector2D(-radius, 0));
			Vector2D right  = markerPosition.add(new Vector2D(radius, 0));
			Vector2D top    = markerPosition.add(new Vector2D(0, -radius));
			Vector2D bottom = markerPosition.add(new Vector2D(0, radius));

			Vector2D endPoints[] = {
				left, right, top, bottom
			};

			for (Vector2D endPoint : endPoints) {
				addVertex(endPoint);

				List<Segment> segments = new ArrayList<Segment>();
				segments.add(new Segment(markerPosition, endPoint));
				addCurve(segments);
			}
		}
	}

	/* 曲線を画面外に出さないように外枠を作る */
	private void createOuterFrame() {
		int windowWidth = width;
		int windowHeight = height;
		Vector2D leftUp    = new Vector2D(0, 0);
		Vector2D rightUp   = new Vector2D(windowWidth - 1, 0);
		Vector2D rightDown = new Vector2D(windowWidth - 1, windowHeight - 1);
		Vector2D leftDown  = new Vector2D(0, windowHeight - 1);

		List<Segment> frame = new ArrayList<Segment>();
		frame.add(new Segment(leftUp, rightUp));
		frame.add(new Segment(rightUp, rightDown));
		frame.add(new Segment(rightDown, leftDown));
		frame.add(new Segment(leftDown, leftUp));

		addCurve(frame);
	}

	/* 頂点を追加 */
	private void addVertex(Vector2D position) {
		Vertex vertex = new Vertex(position);
		data.addVertex(vertex);
	}

	/* 曲線を追加(追加時には交差判定は行われない) */
	private void addCurve(List<Segment> segments) {
		final color col = color(0, 0, 0);
		Curve curve = new Curve(segments, col);
		data.addCurve(curve);
	}

	/*------ ここからゲーム進行に関わるメソッド ------*/

	void update() {
		data.update();

		/* ターンが終了していたら, それを GameManager に伝える */
		if (turnEnded) {
			gameManager.informEndOfTurn();
			turnEnded = false;
		}

		/* 終了処理; TODO: もっとわかりやすく */
		if (turnMax == turnCount) {
			printf.set("The game has finished.");
		}
	}

	/* 新しい曲線を描き始める; TODO: Vector2D でなくて vertex にする手もある? */
	void startDrawing(Vector2D position, color col) {
		startSelected = data.fetchVertex(position);		//クリックした場所にある頂点を取ってくる
		if (startSelected == null) return;
		Vector2D start = startSelected.getPosition();

		curveActive = new CurveActive(start, col);		// その頂点から直線を引き始める
		data.setCurveActive(curveActive);

		startSelected.connect();						// 頂点の次数を増やす
	}

	/* 曲線の中継点を置く */
	void putRelayPoint(Vector2D position) {
		if (curveActive == null) return;
		curveActive.extend(position);		// 描き途中の直線を更新
	}

	/* 直線を描き終える */
	void endDrawing(Vector2D position, color solidifiedCol) {
		if (curveActive == null) return;			// そもそも curveActive がないなら終了

		endSelected = data.fetchVertex(position);	// 終点にある頂点を取ってくる
		startSelected.disconnect();					// いったん始点の接続を切っておく

		/* もし頂点が存在したなら */
		if (endSelected != null) {
			Vector2D end = endSelected.getPosition();
			curveActive.terminate(end); 		// 頂点の座標で終端する(当たり判定に抜けが出ないように)

			/* 他の曲線と交差していなければ */
			if (!collisionDetector.collisionExists()) {
				Curve curve = curveActive.solidify(end, solidifiedCol);	// curveActive を solidify する
				List<Curve> pair = curve.split();	// 曲線を分割する
				data.addCurve(pair.get(0));
				data.addCurve(pair.get(1));

				/* 両端点を接続 */
				startSelected.connect();
				endSelected.connect();

				/* 新しいマーカーを作る */
				createNewMarker(curve.getCenterSegment());

				/* ターン終了! */
				turnEnded = true;	// ターン終了のフラグを立てる
				++turnCount;
			}
		}

		/* curveActive を消去 */
		data.resetCurveActive();
		curveActive = null;
		startSelected = null;
		endSelected = null;
	}

	/* 曲線の1セグメントを受け取り, それに直交するように線を引いて新しいマーカーを作る;
	   TODO: 途中のロジックをなんとかする */
	private void createNewMarker(Segment segment) {
		Vector2D a = segment.start();
		Vector2D b = segment.end();

		Vector2D middlePoint = segment.middlePoint();		// 中点
		Vector2D vector = segment.toVector();				// 線分を有向線分と思ったときのベクトル
		Vector2D normal = new Vector2D(-vector.y(), vector.x());		// 法線ベクトル

		int tmpRadius = 54;		// マーカーの大きさ

		/* 新しい線分が他の線分に交差しなくなるまで、 radius を 2 / 3 にしつづける */
		while (true) {
			Vector2D tmpModified = normal.mul(tmpRadius / normal.norm());
			Vector2D tmpPointA = middlePoint.add(tmpModified);
			Vector2D tmpPointB = middlePoint.sub(tmpModified);
			Segment tmpSegmentA = new Segment(middlePoint, tmpPointA);
			Segment tmpSegmentB = new Segment(middlePoint, tmpPointB);
			if (canLocate(tmpSegmentA) && canLocate(tmpSegmentB)) break;
			tmpRadius = tmpRadius * 2 / 3;
		}

		/* 実際に新しいマーカーを作る(上で決めた最大長の半分の長さ) */
		int radius = tmpRadius / 2;
		Vector2D normalModified = normal.mul(radius / normal.norm());	// 長さを調整した法線ベクトル
		Vector2D pointA = middlePoint.add(normalModified);
		Vector2D pointB = middlePoint.sub(normalModified);
		Segment newSegmentA = new Segment(middlePoint, pointA);
		Segment newSegmentB = new Segment(middlePoint, pointB);

		/* 頂点と線分を追加 */
		addVertex(pointA);
		addVertex(pointB);
		List<Segment> listA = new ArrayList<Segment>();
		List<Segment> listB = new ArrayList<Segment>();
		listA.add(newSegmentA);
		listB.add(newSegmentB);
		addCurve(listA);
		addCurve(listB);
	}

	/* 線分を置けるかどうかチェック; TODO: もっとうまい方法を考える */
	private boolean canLocate(Segment segment) {
		for (Curve curve : data.getCurves()) {
			for (Segment object : curve) {
				if (MathUtility.intersects(segment, object)) {
					return false;
				}
			}
		}
		return true;
	}
}

/*-----------------------------*/
/*--------   Player   ---------*/
/*-----------------------------*/

interface Player {
	void update();
	void activate();
	void deactivate();
}

/*-----------------------------*/
/*---------   Human   ---------*/
/*-----------------------------*/

/* 人力操作するプレイヤー; マウス入力を受け取り、適切なコマンドを Judge に与える
   (曲線の中継点の間引きはここで行うことにした) */
class Human implements Player, MouseEventListener {
	final GameManager gameManager;		// コールバック用
	final Judge judge;

	final int playerNum;
	boolean isActive = false;			// 自分のターンかどうか

	TimerForCurve timer;				// 曲線を引くときの中継点の間引き用

	color curveCol;						// 曲線を引く時の色
	color curveActiveCol;

	Human(GameManager gameManager_, int playerNum_) {
		gameManager = gameManager_;
		playerNum = playerNum_;

		/* GameManager に尋ね、必要なオブジェクトの参照を受け取る */
		judge = gameManager.getJudge();
		curveCol = gameManager.getCurveColor(playerNum);
		curveActiveCol = gameManager.getCurveActiveColor(playerNum);

		/* 自身をマウスイベントリスナーとして登録 */
		MouseEventDetector.add(this);
	}

	/* 毎フレーム更新(press, release はこれとは別に割り込みで判定) */
	void update() {
		if (!isActive) return;			// 自分のターンでない間は何もしない
		if (mousePressed) {
			if (timer == null) return;	// timer が null なら何もしない(マウスクリック後に active になると起こりうる);
										// TODO: timer 以外の状態を持って判定すべき?
			Vector2D mousePosition = new Vector2D(mouseX, mouseY);

			timer.update(mousePosition);
			if (timer.elapsed()) {		// 一定の長さ以上動かしたときだけ点を追加
				judge.putRelayPoint(mousePosition);
			}
		}
	}

	/* マウスが押された瞬間 */
	void mouseIsPressed(Vector2D position) {
		if (!isActive) return;
		judge.startDrawing(position, curveActiveCol);		// 描き始める

		final int interval = 15;	// マウスが累計で interval の長さ動くごとに点を追加する
		timer = new TimerForCurve(position, interval);
	}

	/* マウスが離された瞬間 */
	void mouseIsReleased(Vector2D position) {
		if (!isActive) return;
		judge.endDrawing(position, curveCol);				// 描き終える

		timer = null;
	}

	/* 自分のターンになったことを外から知らせるためのメソッド */
	void activate() {
		isActive = true;
	}

	/* 自分のターンが終わったことを外から知らせるためのメソッド */
	void deactivate() {
		isActive = false;
	}
}

/*-----------------------------*/
/*------   GameManager   ------*/
/*-----------------------------*/

/* ゲームオブジェクトの生成、保持と更新を行う */
class GameManager {
	final FieldData data;
	final CollisionDetector collisionDetector;
	final Judge judge;
	final Player first;		// 先手
	final Player second;	// 後手

	Player active;			// 現在手番を得ているプレーヤー (first や second と同じ参照を持つ)
	Player inactive;		// 現在手番でないプレーヤー

	int turn = 0;			// 何人目のターンか (0-based)

	GameManager() {
		/* ゲームオブジェクト生成 */
		data = new FieldData();
		collisionDetector = new CollisionDetector(data);
		judge = new Judge(this);

		/* プレイヤー生成 */
		first = new Human(this, 0);
		second = new AiPlayer(this, 1);
		active = first;
		inactive = second;

		/* プレイヤーをアクティブ化/非アクティブ化 */
		inactive.deactivate();
		active.activate();
	}

	/* 次のターンに移る */
	void nextTurn() {
		/* active と inactive をスワップ */
		Player tmp = active;
		active = inactive;
		inactive = tmp;

		/* プレイヤーをアクティブ化/非アクティブ化 */
		inactive.deactivate();
		active.activate();
	}

	void update() {
		judge.update();
		collisionDetector.update();
		active.update();
		inactive.update();
	}

	/* 1ターンが終わったことを外(Judge)から知らせるためのメソッド */
	void informEndOfTurn() {
		nextTurn();		// 直ちに次のターンに転換(TODO: 1フレーム待つほうが良い説もある)
	}

	/* 引くべき曲線の色を知りたい Player が尋ねるためのメソッド */
	color getCurveColor(int playerNum){
		final color[] colors = {color(255, 0, 0),  color(0, 0, 255)};
		return colors[playerNum];
	}

	/* 引くべき CurveActive の色を知りたい Player が尋ねるためのメソッド */
	color getCurveActiveColor(int playerNum){
		final color[] colors = {color(255, 128, 128),  color(128, 128, 255)};
		return colors[playerNum];
	}

	/* Field の参照を取得(TODO: ここら辺を public にしておくのはちょっと微妙) */
	FieldData getFieldData() {
		return data;
	}

	/* Judge の参照を取得 */
	Judge getJudge() {
		return judge;
	}

	/* CollisionDetector の参照を取得 */
	CollisionDetector getCollisionDetector() {
		return collisionDetector;
	}
}

/*-----------------------------*/
/*---  MouseEventListener   ---*/
/*-----------------------------*/

/* マウスがクリック/リリースされたときに伝えてもらいたいオブジェクトの基底クラス */
interface MouseEventListener {
	void mouseIsPressed(Vector2D position);
	void mouseIsReleased(Vector2D position);
}

/*-----------------------------*/
/*---  MouseEventDetector   ---*/
/*-----------------------------*/

/* 登録された MouseEventListener にマウスイベントを伝える */
static class MouseEventDetector {
	static List<MouseEventListener> listeners = new ArrayList<MouseEventListener>();

	/* MouseEventListener を登録 */
	static void add(MouseEventListener listener) {
		listeners.add(listener);
	}

	/* マウスがクリックされた(グローバルから呼ぶ) */
	static void mouseIsPressed(Vector2D position) {
		for (MouseEventListener listener : listeners) {
			listener.mouseIsPressed(position);
		}
	}

	/* マウスが離された(グローバルから呼ぶ) */
	static void mouseIsReleased(Vector2D position) {
		for (MouseEventListener listener : listeners) {
			listener.mouseIsReleased(position);
		}
	}
}

/* デバッグ用 */
class Printf implements Displayable {
	String str = new String();

	void set(String str_) {
		str = str_;
	}

	void display() {
		final color col = color(0, 0, 0);
		fill(col);
		textSize(32);

		text(str, 50, 50);
	}
}

/* GameManager */
GameManager gameManager;

/* static class にできないためにグローバルにおいている変数 */
Printf printf = new Printf();
DrawingTools drawingTools = new DrawingTools();

/* 全体の初期化 */
void setup() {
	size(960, 720);
	colorMode(RGB, 256);		// RGB 256 階調で色設定を与える

	/* 初期化 */
	gameManager = new GameManager();	// グローバルで初期化すると画面サイズが定まっていないなどの理由で問題があるので、ここで初期化
	Displayer.add(printf, 100000000);
}

/* 毎フレーム実行 */
void draw() {
	background(color(255, 255, 255));

	gameManager.update();
	Displayer.update();
}

void mousePressed() {
	if (mouseButton == RIGHT) return;						// 右クリックのときは何もしない

	Vector2D mousePosition = new Vector2D(mouseX, mouseY);
	MouseEventDetector.mouseIsPressed(mousePosition);		// MouseEventDetector に伝える
}

void mouseReleased() {
	if (mouseButton == RIGHT) return;						// 右クリックのときは何もしない

	Vector2D mousePosition = new Vector2D(mouseX, mouseY);
	MouseEventDetector.mouseIsReleased(mousePosition);		// MouseEventDetector に伝える
}
