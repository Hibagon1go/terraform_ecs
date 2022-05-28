resource "aws_security_group" "alb" {
  name        = "handson-alb"
  description = "handson alb"
  vpc_id      = aws_vpc.main.id

  # セキュリティグループ内のリソースからインターネットへのアクセスを許可する
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "handson-alb"
  }
}

resource "aws_security_group_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  # セキュリティグループ内のリソースへインターネットからのアクセスを許可する
  type = "ingress"

  from_port = 80
  to_port   = 80
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb" "main" {
  load_balancer_type = "application"
  name               = "handson"

  security_groups = ["${aws_security_group.alb.id}"]
  subnets         = ["${aws_subnet.public_1a.id}", "${aws_subnet.public_1c.id}", "${aws_subnet.public_1d.id}"]
}


resource "aws_lb_listener" "main" {
  # HTTPでのアクセスを受け付ける
  port     = "80"
  protocol = "HTTP"

  # ALBのarnを指定します。
  #XXX: arnはAmazon Resource Names の略で、その名の通りリソースを特定するための一意な名前(id)です。
  load_balancer_arn = aws_lb.main.arn

  # "ok" という固定レスポンスを設定する
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "ok"
    }
  }
}

resource "aws_lb_target_group" "main" {
  name = "handson"

  # ターゲットグループを作成するVPC
  vpc_id = aws_vpc.main.id

  # ALBからECSタスクのコンテナへトラフィックを振り分ける設定
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"

  # コンテナへの死活監視設定
  health_check {
    port = 80
    path = "/"
  }
}

/* これだと、httpsにリダイレクトするよりも先に、ecsに投げられる
resource "aws_lb_listener_rule" "main" {
  # ルールを追加するリスナー
  listener_arn = aws_lb_listener.main.arn

  # 受け取ったトラフィックをターゲットグループへ受け渡す
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.id
  }

  # ターゲットグループへ受け渡すトラフィックの条件
  condition {
    path_pattern {
      values = ["*"]
    }
  }
}
*/

resource "aws_lb_listener" "https" {
  depends_on = [aws_acm_certificate_validation.main]

  load_balancer_arn = aws_lb.main.arn

  certificate_arn = aws_acm_certificate.main.arn

  port     = "443"
  protocol = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.id
  }
}

resource "aws_lb_listener_rule" "http_to_https" {
  listener_arn = aws_lb_listener.main.arn

  priority = 99

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["${var.domain}"]
    }
  }
}

resource "aws_security_group_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id

  type = "ingress"

  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]
}
