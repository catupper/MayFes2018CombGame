import java.util.*;

class Triangulation {
	class Edge {
		int from;
		int to;

		Edge(int from_, int to_) {
			from = from_;
			to = to_;
		}

		int from() {
			return from;
		}

		int to() {
			return to;
		}

		Segment toSegment() {
			return new Segment(vertices.get(from), vertices.get(to));
		}

		String toString() {
			return "[" + from + ", " + to + "]";
		}
	}

	class Triangle {
		final int[] indices = new int[3];

		Triangle(int ia_, int ib_, int ic_) {
			indices[0] = ia_;
			indices[1] = ib_;
			indices[2] = ic_;
			Arrays.sort(indices);
		}

		int get(int i) {
			if (i < 0 || i >= 3) throw new IndexOutOfBoundsException();
			return indices[i];
		}

		public boolean equals(Object obj) {
			if (!(obj instanceof Triangle)) return false;

			Triangle other = (Triangle)obj;
			return Arrays.equals(indices, other.indices);
		}

		public int hashCode() {
			return Arrays.hashCode(indices);
		}

		String toString() {
			return "[" + indices[0] + ", " + indices[1] + ", " + indices[2] + "]";
		}
	}

	List<Vector2D> vertices;
	Graph graph;
	int size;

	List<Edge> choosedList;
	List<Edge> pendingList;

	Map<Triangle, Integer> indexOfTriangle;
	List<Triangle> triangles;
	Graph dual;

	Triangulation(List<Vector2D> vertices_, Graph graph_) {
		vertices = new ArrayList<Vector2D>(vertices_);
		graph = new Graph(graph_);
		size = graph.size();
	}

	void calculate() {
		boolean[][] needed = new boolean[size][size];
		for (int i = 0; i < size; ++i) {
			for (int j = i + 1; j < size; ++j) {
				needed[i][j] = true;
			}
		}

		/* もとある辺を追加 */
		choosedList = new ArrayList<Edge>();
		for (int from = 0; from < size; ++from) {
			Iterator<Graph.Element> itr = graph.getIterator(from);

			while (itr.hasNext()) {
				Graph.Element element = itr.next();
				int to = element.to();
				if (from >= to) continue;		// 辺を重複して数えない

				choosedList.add(new Edge(from, to));
				needed[from][to] = false;		// 追加したので以後の工程では考えなくてよい
			}
		}
		final int numOfOriginalEdges = choosedList.size();

		/* 残りの辺を長さでソート */
		pendingList = new ArrayList<Edge>();
		for (int i = 0; i < size; ++i) {
			for (int j = i + 1; j < size; ++j) {
				if (needed[i][j]) {
					pendingList.add(new Edge(i, j));
				}
			}
		}

		class ComparatorByLength implements Comparator<Edge> {
			public int compare(Edge a, Edge b) {
				Segment segA = a.toSegment();
				Segment segB = b.toSegment();
				int lenA = segA.length2();
				int lenB = segB.length2();
				if (lenA > lenB) return 1;
				if (lenA < lenB) return -1;
				return 0;
			}
		}
		ComparatorByLength comparatorByLength = new ComparatorByLength();
		pendingList.sort(comparatorByLength);

		/* 他の辺と交わらないように辺を追加していく */
		for (Edge pending : pendingList) {
			boolean intersects = false;
			Segment pendingSegment = pending.toSegment();

			for (Edge choosed : choosedList) {
				Segment choosedSegment = choosed.toSegment();
				if (MathUtility.intersects(choosedSegment, pendingSegment)
					|| pendingSegment.includes(choosedSegment)) {

					intersects = true;
					break;
				}
			}

			if (!intersects) {
				choosedList.add(pending);
				graph.add(pending.from(), pending.to());
				graph.add(pending.to(), pending.from());
				//new DebugLine(new Segment(vertices.get(pending.from()), vertices.get(pending.to())));
			}
		}

		/* 各辺について以下を行う */
		indexOfTriangle = new HashMap<Triangle, Integer>();
		triangles = new ArrayList<Triangle>();
		dual = new Graph();
		for (int i = 0; i < choosedList.size(); ++i) {
			Edge choosed = choosedList.get(i);

			/* 「その辺に付け加えると三角形ができる頂点」を列挙 */
			int vertexA = choosed.from();
			int vertexB = choosed.to();

			List<Integer> complements = new ArrayList<Integer>();
			Set<Integer> set = new HashSet<Integer>();
			Iterator<Graph.Element> itrA = graph.getIterator(vertexA);
			while (itrA.hasNext()) {
				Graph.Element element = itrA.next();
				int to = element.to();
				set.add(to);
			}

			Iterator<Graph.Element> itrB = graph.getIterator(vertexB);
			while (itrB.hasNext()) {
				Graph.Element element = itrB.next();
				int to = element.to();

				if (set.contains(to)) {
					complements.add(to);
				}
			}

			/* 最も辺に「近い」2点だけを取り出す
			   (三角形ができる頂点をすべて選んでしまうのは誤りである: 反例として正四面体をつぶしたような形を考えよ) */
			/* TODO: 雑な実装を直す */
			Integer right = null;
			Integer left = null;
			int rightCrossMin = Integer.MAX_VALUE;
			int leftCrossMax = Integer.MIN_VALUE;
			Vector2D a = vertices.get(vertexA);
			Vector2D b = vertices.get(vertexB);
			for (int complement : complements) {
				Vector2D p = vertices.get(complement);
				Vector2D ab = b.sub(a);
				Vector2D ap = p.sub(a);
				int cross = ab.cross(ap);
				if (cross > 0) {
					if (cross < rightCrossMin) {
						rightCrossMin = cross;
						right = complement;
					}
				} else {
					if (cross > leftCrossMax) {
						leftCrossMax = cross;
						left = complement;
					}
				}
			}

			List<Integer> specials = new ArrayList<Integer>();
			if (right != null) specials.add(right);
			if (left != null) specials.add(left);

			/* 双対グラフを作成 */
			for (Integer special : specials) {
				Triangle triangle = new Triangle(vertexA, vertexB, special);
				if (indexOfTriangle.containsKey(triangle)) continue;

				triangles.add(triangle);
				int index = triangles.size() - 1;
				indexOfTriangle.put(triangle, index);
				dual.resize(index + 1);
			}

			/* 制約辺でなく、かつその辺を使う三角形が2つあるなら、それらの三角形を結ぶ */
			if (i >= numOfOriginalEdges && specials.size() == 2) {
				Triangle triangleA = new Triangle(vertexA, vertexB, specials.get(0));
				Triangle triangleB = new Triangle(vertexA, vertexB, specials.get(1));
				int indexA = indexOfTriangle.get(triangleA);
				int indexB = indexOfTriangle.get(triangleB);
				dual.add(indexA, indexB);
				dual.add(indexB, indexA);
			}
		}
	}

	Graph getTriangulation() {
		return graph;
	}

	Graph getDualGraph() {
		return dual;
	}

	List<Triangle> getVerticesOfDualGraph() {
		return triangles;
	}
}

static class Dijkstra {
	private class Element implements Comparable<Element> {
		int index;
		int previous;
		int distance;

		Element (int index_, int previous_, int distance_) {
			index = index_;
			previous = previous_;
			distance = distance_;
		}

		int previous() {
			return previous;
		}

		int distance() {
			return distance;
		}

		int index() {
			return index;
		}

		int compareTo(Element other) {
			if (distance > other.distance) return 1;
			if (distance < other.distance) return -1;
			if (index > other.index) return 1;
			if (index < other.index) return -1;
			if (previous > other.previous) return 1;
			if (previous < other.previous) return -1;
			return 0;
		}
	}

	final Graph graph;
	final int size;
	int[] previousOf;
	int[] distanceOf;

	static final int INFINITY = Integer.MAX_VALUE;
	static final int IS_SOURCE = -1;

	Dijkstra(Graph graph_) {
		graph = new Graph(graph_);
		size = graph.size();
		previousOf = new int[size];
		distanceOf = new int[size];
	}

	List<Integer> execute(List<Integer> sources, List<Integer> sinks) {
		Arrays.fill(distanceOf, INFINITY);

		PriorityQueue<Element> queue = new PriorityQueue<Element>();
		for (int source : sources) {
			queue.add(new Element(source, IS_SOURCE, 0));
		}

		while (!queue.isEmpty()) {
			Element top = queue.remove();

			int from = top.index();
			int previous = top.previous();
			int distance = top.distance();

			if (distanceOf[from] != INFINITY) continue;
			distanceOf[from] = distance;
			previousOf[from] = previous;

			Iterator<Graph.Element> itr = graph.getIterator(from);
			while (itr.hasNext()) {
				Graph.Element element = itr.next();

				int to = element.to();
				int cost = element.cost();
				queue.add(new Element(to, from, distance + cost));
			}
		}

		/* 復元 */
		Integer nearestSink = null;
		int minDistance = INFINITY;
		for (int sink : sinks) {
			if (distanceOf[sink] < minDistance) {
				minDistance = distanceOf[sink];
				nearestSink = sink;
			}
		}

		List<Integer> path = new ArrayList<Integer>();
		if (nearestSink == null) return path;

		int here = nearestSink;
		while (previousOf[here] != IS_SOURCE) {
			path.add(here);
			here = previousOf[here];
		}
		path.add(here);
		Collections.reverse(path);

		////////System.out.println(previousOf);
		////////System.out.println(distanceOf);
		return path;
	}
}

/*-----------------------------*/
/*-------   AiPlayer   --------*/
/*-----------------------------*/

class AiPlayer implements Player {
	FieldData data;
	Judge judge;
	boolean isActive = false;

	final GameManager gameManager;		// コールバック用
	final int playerNum;

	AiPlayerThread thread;
	AiPlayerThread.Result result;
	int progress;

	color curveCol;
	color curveActiveCol;

	AiPlayer(GameManager gameManager_, int playerNum_) {
		gameManager = gameManager_;
		playerNum = playerNum_;

		data = gameManager.getFieldData();
		judge = gameManager.getJudge();
		curveCol = gameManager.getCurveColor(playerNum);
		curveActiveCol = gameManager.getCurveActiveColor(playerNum);
	}

	void update() {
		if (!isActive) return;
		if (thread == null || thread.isAlive()) return;

		if (progress == -1) {
			judge.startDrawing(result.startPosition, curveActiveCol);
		} else if (progress < result.relayPoints.size()) {
			Vector2D relayPoint = result.relayPoints.get(progress);
			judge.putRelayPoint(relayPoint);
		} else if (progress == result.relayPoints.size()) {
			judge.endDrawing(result.endPosition, curveCol);
		}
		++progress;
	}

	void activate() {
		isActive = true;
		AiPlayerThread tmp = new AiPlayerThread(data, result);
		result = tmp.new Result();
		thread = new AiPlayerThread(data, result);
		thread.start();
		progress = -1;
	}

	void deactivate() {
		isActive = false;
	}
}

class AiPlayerThread extends Thread {
	class Result {
		public Vector2D startPosition;
		public Vector2D endPosition;
		public List<Vector2D> relayPoints;
	}

	FieldData data;
	Result referenceOfResult;

	AiPlayerThread(FieldData data_, Result referenceOfResult_) {
		data = data_;
		referenceOfResult = referenceOfResult_;
	}

	List<Vector2D> points;
	Graph graph;
	List<Integer> vertexIndices;

	void createGraph() {
		List<Vertex> vertices = data.getVertices();
		List<Curve> curves = data.getCurves();

		/* position をすべて集めてくる */
		List<Vector2D> massOfPoints = new ArrayList<Vector2D>();

		for (Vertex vertex : vertices) {
			Vector2D position = vertex.getPosition();
			massOfPoints.add(position);
		}
		for (Curve curve : curves) {
			for (Segment segment : curve) {
				massOfPoints.add(segment.start());
				massOfPoints.add(segment.end());
			}
		}
		//
		/* ランダムに頂点追加 */
		// for (int i = 0; i < 20; ++i) {
		// 	for (int j = 0; j < 20; ++j) {
		// 		Vector2D randPoint = new Vector2D(
		// 			50 + (width - 100) * i / 20 + (int)random(7),
		// 			50 + ((height - 100) * j * 2 + i % 2) / 40 + (int)random(7)
		// 			);
		// 		// Vector2D randPoint = new Vector2D(
		// 		// 	(int)random(50, width - 50),
		// 		// 	(int)random(50, height - 50)
		// 		// 	);
		// 		massOfPoints.add(randPoint);
		// 	}
		// }

		/* position とグラフの頂点を対応付ける */
		Map<Vector2D, Integer> pointToIndex = new HashMap<Vector2D, Integer>();
		for (Vector2D point : massOfPoints) {
			if (pointToIndex.containsKey(point)) continue;
			pointToIndex.put(point, 0);
		}

		points = new ArrayList<Vector2D>();
		for (Vector2D point : pointToIndex.keySet()) {
			points.add(point);
		}

		int index = 0;
		for (Vector2D point : points) {
			pointToIndex.put(point, index);
			++index;
		}

		vertexIndices = new ArrayList<Integer>();
		for (Vertex vertex : vertices) {
			if (vertex.isLocked()) continue;

			Vector2D position = vertex.getPosition();
			int vertexIndex = pointToIndex.get(position);
			vertexIndices.add(vertexIndex);
		}

		/* グラフを作成 */
		int size = points.size();
		graph = new Graph(size);
		for (Curve curve : curves) {
			for (Segment segment : curve) {
				int from = pointToIndex.get(segment.start());
				int to = pointToIndex.get(segment.end());

				graph.add(from, to);
				graph.add(to, from);
			}
		}
	}

	Graph modifiedDualGraph;
	List<Triangulation.Triangle> triangles;
	List<Segment> segments;
	void createDualGraph() {
		createGraph();
		Triangulation triangulation = new Triangulation(points, graph);
		triangulation.calculate();

		Graph dualGraph = triangulation.getDualGraph();
		triangles = triangulation.getVerticesOfDualGraph();

		for (int i = 0; i < dualGraph.size(); ++i) {
			dualGraph.add(i, i);		// 後の便宜上自己ループを追加(そうしないと連結でありながらたどり着けない頂点ができてしまう)
		}

		segments = new ArrayList<Segment>();
		List<List<Integer>> triToSeg = new ArrayList<List<Integer>>(triangles.size());
		for (int i = 0; i < triangles.size(); ++i) {
			triToSeg.add(new ArrayList<Integer>());
		}

		for (int i = 0; i < triangles.size(); ++i) {
			Triangulation.Triangle triangle = triangles.get(i);
			Vector2D[] middlePoints = new Vector2D[3];
 			for (int k = 0; k < 3; ++k) {
				Vector2D a = points.get(triangle.get(k));
				Vector2D b = points.get(triangle.get((k + 1) % 3));
				middlePoints[k] = a.add(b).div(2);
			}

			for (int k = 0; k < 3; ++k) {
				for (int p = 0; p < 3; ++p) {
					if (k == p) continue;
					Segment segment = new Segment(middlePoints[k], middlePoints[p]);
					segments.add(segment);
					triToSeg.get(i).add(segments.size() - 1);
				}
			}
		}

		for (int vertexIndex : vertexIndices) {
			for (int i = 0; i < triangles.size(); ++i) {
				Triangulation.Triangle triangle = triangles.get(i);
				boolean isCommon = false;
				for (int k = 0; k < 3; ++k) {
					if (triangle.get(k) == vertexIndex) {
						isCommon = true;
					}
				}
				if (!isCommon) continue;

				List<Integer> notCommon = new ArrayList<Integer>();
				for (int k = 0; k < 3; ++k) {
					if (triangle.get(k) != vertexIndex) {
						notCommon.add(triangle.get(k));
					}
				}

				Vector2D a = points.get(notCommon.get(0));
				Vector2D b = points.get(notCommon.get(1));
				Vector2D middlePoint = a.add(b).div(2);

				Segment segmentIn = new Segment(points.get(vertexIndex), middlePoint);
				Segment segmentOut = new Segment(middlePoint, points.get(vertexIndex));
				segments.add(segmentIn);
				segments.add(segmentOut);
				triToSeg.get(i).add(segments.size() - 2);
				triToSeg.get(i).add(segments.size() - 1);
			}
		}

		/* 線分を結んだグラフを作る */
		modifiedDualGraph = new Graph(segments.size());
		for (int from = 0; from < dualGraph.size(); ++from) {
			Iterator<Graph.Element> itr = dualGraph.getIterator(from);
			while (itr.hasNext()) {
				Graph.Element element = itr.next();
				int to = element.to();

				for (int s : triToSeg.get(from)) {
					for (int t : triToSeg.get(to)) {
						Segment a = segments.get(s);
						Segment b = segments.get(t);

						if (a.end().equals(b.start())) {
							double curvature = MathUtility.angle(a.start(), a.end(), b.end()) - PI;
							modifiedDualGraph.add(s, t, (int)(1000 * curvature * curvature));
						}
					}
				}
			}
		}
	}


	void run() {
		createDualGraph();

		//////System.out.println(modifiedDualGraph);

		Dijkstra dijkstra = new Dijkstra(modifiedDualGraph);

		List<List<Integer>> paths = new ArrayList<List<Integer>>();
		for (int vertexIndex : vertexIndices) {
			List<Integer> sources = new ArrayList<Integer>();
			List<Integer> sinks = new ArrayList<Integer>();

			Vector2D vertexPoint = points.get(vertexIndex);
			for (int i = 0; i < segments.size(); ++i) {
				Segment segment = segments.get(i);
				if (segment.start().equals(vertexPoint)) {
					sources.add(i);
				}

				boolean isSink = false;
				for (int other : vertexIndices) {
					if (other == vertexIndex) continue;

					Vector2D otherPoint = points.get(other);
					if (segment.end().equals(otherPoint)) {
						isSink = true;
					}
				}
				if (isSink) {
					sinks.add(i);
				}

			}

			//System.out.println(sources);
			//System.out.println(sinks);

			List<Integer> path = dijkstra.execute(sources, sinks);
			if (!path.isEmpty()) {
				paths.add(path);
			}
		}


		////System.out.println(sources);
		////System.out.println(sinks);
		////System.out.println(path);
		if (paths.isEmpty())  {
			throw new IllegalStateException();	// ここには来ないはず
		}

		Collections.shuffle(paths);
		List<Integer> path = paths.get(0);

		Vector2D startPosition = segments.get(path.get(0)).start();
		Vector2D endPosition = segments.get(path.get(path.size() - 1)).end();
		List<Vector2D> relayPoints = new ArrayList<Vector2D>();
		for (int i = 1; i < path.size(); ++i) {
			relayPoints.add(segments.get(path.get(i)).start());
		}

		referenceOfResult.startPosition = startPosition;
		referenceOfResult.endPosition = endPosition;
		referenceOfResult.relayPoints = relayPoints;
	}
}
