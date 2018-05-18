import java.util.*;

static class Constant {
	static final int initialDepthVertex = 10000;
	static final int initialDepthCurve = 0;
	static final int initialDepthCurveActive = 1000;
	static final int initialDepthCollision = 100000;
	static final int initialDepthTurnSign = 1000000;
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

	/* 全消去 */
	static void clear() {
		objectToDepth = new HashMap<Displayable, Integer>();
		map = new TreeMap<Integer, List<Displayable>>();
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
		line(
			(float)(from.x().toDouble()), (float)(from.y().toDouble()),
			(float)(to.x().toDouble()), (float)(to.y().toDouble())
		);
	}

	void drawLine(Segment segment) {
   		drawLine(segment, colorRef(0, 0, 0));
	}

	void drawLineForDebug(Segment segment) {
		strokeWeight(1);
		Vector2D from = segment.start();
		Vector2D to = segment.end();
		line(
			(float)(from.x().toDouble()), (float)(from.y().toDouble()),
			(float)(to.x().toDouble()), (float)(to.y().toDouble())
		);
	}

	/* 円を描く */
	void drawCircle(Vector2D position, float radius, color col) {
		fill(col);
		noStroke();
		ellipse((float)(position.x().toDouble()), (float)(position.y().toDouble()), radius * 2, radius * 2);
	}

	void drawCircle(Vector2D position, float radius) {
	   	drawCircle(position, radius, colorRef(0, 0, 0));
	}

	void drawText(Vector2D position, String string, color col) {
		fill(col);
		textSize(32);
		text(string, (float)(position.x().toDouble()), (float)(position.y().toDouble()));
	}

	void drawText(Vector2D position, String string) {
		textAlign(CENTER, CENTER);
		drawText(position, string, colorRef(0, 0, 0));
	}

	void drawRect(Rectangle rectangle, color col) {
		fill(col);
		noStroke();
		rect(rectangle.left(), rectangle.top(), rectangle.width(), rectangle.height(), 20);
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
		final color unlockedColor = colorRef(224, 224, 224, 64);	// 次数が限界に達していない頂点の色
		final color mouseOverColor = colorRef(112, 112, 255);	// 次数が限界に達していない頂点のマウスオーバー時の色

		switch (state) {
		case Unlocked:
			drawingTools.drawCircle(position, radius, unlockedColor);
			break;
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
		return diff.norm2().compareTo(new Rational(radius * radius)) <= 0;
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

	Vector2D getStartPoint() {
		if (segments.size() == 0) return null;
		return segments.get(0).start();
	}

	Vector2D getEndPoint() {
		if (segments.size() == 0) return null;
		return segments.get(segments.size() - 1).end();
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

	/* 折れ線のセグメント数 */
	int size() {
		return segments.size();
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

	Vector2D getStartPoint() {
		if (segments.size() == 0) return null;
		return segments.get(0).start();
	}

	Vector2D getEndPoint() {
		if (segments.size() == 0) return null;
		return segments.get(segments.size() - 1).end();
	}

	Segment getLastSegment() {
		if (segments.size() == 0) return null;
		return segments.get(segments.size() - 1);
	}

	Segment getSegment(int index) {
		return segments.get(index);
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

	/* 中心座標が厳密に position であるような頂点を返す; なければ null を返す */
	Vertex fetchVertexExactly(Vector2D position) {
		for (Vertex vertex : vertices) {
			if (vertex.isLocked()) continue;		// 次数限界の点は選ばない
			if (vertex.getPosition().equals(position)) {
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
				if (MathUtility.intersectsStrictly(subject, object)) {
					Vector2D intersectionPoint = MathUtility.intersectionPoint(subject, object);

					boolean curveActiveCondition =
						intersectionPoint.equals(curveActive.getStartPoint())
						|| intersectionPoint.equals(curveActive.getEndPoint());
					boolean curveCondition =
						intersectionPoint.equals(curve.getStartPoint())
						|| intersectionPoint.equals(curve.getEndPoint());
					if (curveActiveCondition && curveCondition) { 	// 始点や終点ならぶつかっても OK(例外的状況)
						continue;
					}
					list.add(intersectionPoint);
				}
			}
		}

		/* curveActive との交差判定 */
		for (int i = 0; i < curveActive.size() - 2; ++i) {
			Segment object = curveActive.getSegment(i);
			if (MathUtility.intersectsStrictly(subject, object)) {
				Vector2D intersectionPoint = MathUtility.intersectionPoint(subject, object);
				if (i == curveActive.size() - 1
					&& intersectionPoint == object.end()) {	// 始点や終点ならぶつかっても OK
					continue;
				}
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
/*---------   Region   --------*/
/*-----------------------------*/

static class Rectangle {
	int top;
	int bottom;
	int left;
	int right;

	Rectangle(int top_, int bottom_, int left_, int right_) {
		if (top_ > bottom_) throw new IllegalArgumentException();
		if (left_ > right_) throw new IllegalArgumentException();

		top = top_;
		bottom = bottom_;
		left = left_;
		right = right_;
	}

	int top() {
		return top;
	}

	int bottom() {
		return bottom;
	}

	int left() {
		return left;
	}

	int right() {
		return right;
	}

	int height() {
		return bottom - top;
	}

	int width() {
		return right - left;
	}

	boolean includes(Vector2D position) {
		if (position.x().compareTo(new Rational(left())) < 0) return false;
		if (position.x().compareTo(new Rational(right())) > 0) return false;
		if (position.y().compareTo(new Rational(top())) < 0) return false;
		if (position.y().compareTo(new Rational(bottom())) > 0) return false;
		return true;
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

	final Rectangle region;

	/* CurveActive に関する状態 */
	CurveActive curveActive = null;		// 描き途中の曲線
	Vertex startSelected = null;		// curveActive の始点
	Vertex endSelected = null;			// curveActive の終点

	final int markerMax;					// マーカー数
	final int turnMax;						// このゲームが結局何ターンで終了してしまうか
	int turnCount = 0;						// 現在のターン数
	boolean turnEnded = false;				// ターンエンドのフラグ(update 内で用いる)

	Judge(GameManager gameManager_, int numberOfMarkers) {
		gameManager = gameManager_;

		/* GameManager に尋ね、必要なオブジェクトの参照を受け取る */
		data = gameManager.getFieldData();
		collisionDetector = gameManager.getCollisionDetector();

		/* サイズを決定 */
		final int regionTop = 120;
		final int regionLeft = 0;
		final int regionHeight = 720;
		final int regionWidth = 960;
		region = new Rectangle(regionTop, regionTop + regionHeight, regionLeft, regionLeft + regionWidth);

		markerMax = numberOfMarkers;
		turnMax = 5 * markerMax - 2;
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

	boolean gameIsOver() {
		return turnCount >= turnMax;
	}

	/* 十字型マーカーの位置を決める */
	private List<Vector2D> decideMarkerPositions() {
		Vector2D offset = new Vector2D(region.left(), region.top());
		final int windowWidth = region.width();
		final int windowHeight = region.height();
		Vector2D center = offset.add(new Vector2D(windowWidth / 2, windowHeight / 2));	// 中心
		Vector2D circle = new Vector2D(windowWidth / 5, windowHeight / 4);				// 楕円半径
		final int uncertainty = 30;		// ゆらぎ

		List<Vector2D> markerPositions = new ArrayList<Vector2D>();
		for (int i = 0; i < markerMax; ++i) {
			float angleParameter;
			if (markerMax == 2) {
				angleParameter = 0;
			} else {
				angleParameter = HALF_PI;
			}

			Vector2D diff = new Vector2D(
				(int)((float)(circle.x().toDouble()) * cos(TWO_PI * i / markerMax - angleParameter)),
				(int)((float)(circle.y().toDouble()) * sin(TWO_PI * i / markerMax - angleParameter))
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
		Vector2D offset = new Vector2D(region.left(), region.top());
		final int windowWidth = region.width();
		final int windowHeight = region.height();
		Vector2D leftUp    = offset.add(new Vector2D(0, 0));
		Vector2D rightUp   = offset.add(new Vector2D(windowWidth - 1, 0));
		Vector2D rightDown = offset.add(new Vector2D(windowWidth - 1, windowHeight - 1));
		Vector2D leftDown  = offset.add(new Vector2D(0, windowHeight - 1));

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
	}

	/* 新しい曲線を描き始める */
	void startDrawing(Vertex vertex, color col) {
		if (vertex == null) return;
		startSelected = vertex;
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

	/* 曲線を描き終える */
	void endDrawing(Vertex vertex, color solidifiedCol) {
		if (curveActive == null) return;			// そもそも curveActive がないなら終了

		endSelected = vertex;
		startSelected.disconnect();					// いったん始点の接続を切っておく

		/* 頂点のあるところで描き終わったとき */
		if (endSelected != null) {
			Vector2D end = endSelected.getPosition();
			curveActive.terminate(end); 				// 頂点の座標で終端する(当たり判定に抜けが出ないように)

			/* 他の曲線と交差していなければ */
			if (!collisionDetector.collisionExists()) {
				Curve curve = curveActive.solidify(end, solidifiedCol);		// curveActive を solidify する
				List<Curve> pair = curve.split();		// 曲線を分割する
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
		Vector2D normal = new Vector2D(vector.y().negate(), vector.x());		// 法線ベクトル

		int tmpRadius = 54;		// マーカーの大きさ

		/* 新しい線分が他の線分に交差しなくなるまで、 radius を 2 / 3 にしつづける */
		while (true) {
			Vector2D tmpModified = normal.mul(new Rational(tmpRadius, (int)normal.norm()));
			Vector2D tmpPointA = middlePoint.add(tmpModified);
			Vector2D tmpPointB = middlePoint.sub(tmpModified);
			Segment tmpSegmentA = new Segment(middlePoint, tmpPointA);
			Segment tmpSegmentB = new Segment(middlePoint, tmpPointB);
			if (canLocate(tmpSegmentA) && canLocate(tmpSegmentB)) break;
			tmpRadius = tmpRadius * 2 / 3;
		}

		/* 実際に新しいマーカーを作る(上で決めた最大長の半分の長さ) */
		int radius = tmpRadius / 2;
		Vector2D normalModified = normal.mul(new Rational(radius, (int)normal.norm()));	// 長さを調整した法線ベクトル
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
	final FieldData data;

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
		data = gameManager.getFieldData();
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
		Vertex startVertex = data.fetchVertex(position);		// 頂点をとってくる
		judge.startDrawing(startVertex, curveActiveCol);		// 描き始める

		final int interval = 15;	// マウスが累計で interval の長さ動くごとに点を追加する
		timer = new TimerForCurve(position, interval);
	}

	/* マウスが離された瞬間 */
	void mouseIsReleased(Vector2D position) {
		if (!isActive) return;
		Vertex endVertex = data.fetchVertex(position);		// 頂点をとってくる(null でも endDrawing に渡す)
		judge.endDrawing(endVertex, curveCol);				// 描き終える

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
/*-------   TurnSign   --------*/
/*-----------------------------*/

/* どっちの手番か示す */
class TurnSign implements Displayable {
	final GameManager gameManager;
	final Rectangle region;
	int turn = 0;

	boolean gameIsOver = false;

	TurnSign(GameManager gameManager_) {
		gameManager = gameManager_;

		/* サイズを決定 */
		final int regionTop = 0;
		final int regionLeft = 0;
		final int regionHeight = 120;
		final int regionWidth = 960;
		region = new Rectangle(regionTop, regionTop + regionHeight, regionLeft, regionLeft + regionWidth);
	}

	void toggle() {
		++turn;
	}

	void displayTurn() {
		Vector2D offset = new Vector2D(region.left(), region.top());
		if (!gameIsOver) {
			color col = gameManager.getCurveColor(turn % 2);
			Vector2D position = null;
			String string = null;
			switch (turn % 2) {
			case 0:
				position = new Vector2D(150, 40);
				string = "あなたのターン";
				break;
			case 1:
				position = new Vector2D(region.width() - 150, 40);
				string = "あいてのターン";
				break;
			}
			drawingTools.drawText(offset.add(position), string, col);
		}

		int turnModified = 0; 	// ゲーム終了後かどうかでターン数を調整します
		if (gameIsOver) {
			turnModified = turn;
		} else {
			turnModified = turn + 1;
		}

		Vector2D positionCenter = new Vector2D(region.width() / 2, 40);
		String stringCenter = "ターン " + turnModified;
		drawingTools.drawText(offset.add(positionCenter), stringCenter, colorRef(0, 0, 0));
	}

	void displayWinner() {
		Vector2D offset = new Vector2D(region.left(), region.top());
		Vector2D position = new Vector2D(region.width() / 2, 90);
		if (gameIsOver) {
			String string = null;
			if (turn % 2 == 0) {
				string = "あなたのまけ…";
			} else {
				string = "あなたのかち！";
			}
			drawingTools.drawText(offset.add(position), string, colorRef(0, 0, 0));
		}
	}

	void display() {
		displayTurn();
		displayWinner();
	}

	void notifyGameOver() {
		gameIsOver = true;
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

	TurnSign turnSign;
	boolean gameIsOver = false;

	GameManager(int numberOfMarkers) {
		/* ゲームオブジェクト生成 */
		data = new FieldData();
		collisionDetector = new CollisionDetector(data);
		judge = new Judge(this, numberOfMarkers);
		turnSign = new TurnSign(this);
		Displayer.add(turnSign, Constant.initialDepthTurnSign);

		/* プレイヤー生成 */
		first = new Human(this, 0);
		second = new AiPlayer(this, 1);
		active = first;
		inactive = second;

		/* プレイヤーをアクティブ化/非アクティブ化 */
		inactive.deactivate();
		active.activate();
	}

	boolean gameIsOver() {
		return gameIsOver;
	}

	/* 次のターンに移る */
	void nextTurn() {
		if (judge.gameIsOver()) {		// ゲームが終了している
			active.deactivate();
			turnSign.toggle();
			turnSign.notifyGameOver();
			gameIsOver = true;
		} else {
			/* active と inactive をスワップ */
			Player tmp = active;
			active = inactive;
			inactive = tmp;

			/* プレイヤーをアクティブ化/非アクティブ化 */
			inactive.deactivate();
			active.activate();

			turnSign.toggle();
		}
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

class Button implements MouseEventListener, Displayable {
	boolean isPressed = false;
	Rectangle region;
	String text;

	Button(Rectangle region_, String text_) {
		region = region_;
		text = text_;
		MouseEventDetector.add(this);
	}

	void mouseIsPressed(Vector2D position) {
		if (region.includes(position)) {
			isPressed = true;
		}
	}

	void mouseIsReleased(Vector2D position) {}

	boolean isPressed() {
		return isPressed;
	}

	void display() {
		Vector2D mousePosition = new Vector2D(mouseX, mouseY);
		color col;
		if (region.includes(mousePosition)) {
			col = colorRef(128, 128, 224);
		} else {
			col = colorRef(192, 192, 192);
		}
		drawingTools.drawRect(region, col);
		drawingTools.drawText(new Vector2D(region.left() + region.width() / 2, region.top() + region.height() / 2), text);
	}
}

class Application {
	GameManager gameManager;
	Button twoMarkers;
	Button threeMarkers;
	Button again;
	int state = 0;

	Application() {
		initialize();
	}

	void update() {
		if (state == 0) {
			drawingTools.drawText(new Vector2D(960 / 2, 160), "十字マーカーのかず:");
			if (twoMarkers.isPressed()) {
				Displayer.clear();
				gameManager = new GameManager(2);
				state = 1;
			}
			if (threeMarkers.isPressed()) {
				Displayer.clear();
				gameManager = new GameManager(3);
				state = 1;
			}
		} else if (state == 1) {
			gameManager.update();

			if (gameManager.gameIsOver() && again == null) {
				again = new Button(new Rectangle(700, 800, 640, 880), "もう一回");
				Displayer.add(again, 6000000);
			}

			if (again != null && again.isPressed()) {
				state = 0;
				initialize();
			}
		}
	}

	void initialize() {
		Displayer.clear();
		gameManager = null;
		again = null;

		int x0 = 200;
		int x1 = 450;
		int y0 = 200;
		int y1 = 360;
		twoMarkers = new Button(new Rectangle(y0, y1, x0, x1), "2こ");
		threeMarkers = new Button(new Rectangle(y0, y1, 960 - x1, 960 - x0), "3こ");
		Displayer.add(twoMarkers, 1000);
		Displayer.add(threeMarkers, 1001);
	}



}

Application theApplication;

/* static class にできないためにグローバルにおいている変数 */
Printf printf = new Printf();
DrawingTools drawingTools = new DrawingTools();

/* 全体の初期化 */
void setup() {
	size(960, 840);
	colorMode(RGB, 256);		// RGB 256 階調で色設定を与える
	PFont font = createFont("MS Gothic", 48, true);
	textFont(font);

	/* 初期化 */
	theApplication = new Application();
	Displayer.add(printf, 100000000);
}

/* 毎フレーム実行 */
void draw() {
	background(color(255, 255, 255));
	
	theApplication.update();
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
