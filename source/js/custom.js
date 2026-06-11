// custom.js - 评论按钮 + 朋友圈样式 + 阅读进度 + 你好标题
document.addEventListener('DOMContentLoaded', function () {
  var COMMENT_EMAIL = 'dwinnie137@gmail.com';
  var isPost = !!document.getElementById('article-container');
  var isHome = !!document.getElementById('recent-posts');

  // 首页：你好标题 + 朋友圈卡片样式
  if (isHome) {
    var st = document.getElementById('site-title');
    if (st) st.textContent = '你好~';

    document.querySelectorAll('.recent-post-item').forEach(function (c) {
      var isShort = false;
      var cats = c.querySelectorAll('.article-meta__categories a');
      for (var i = 0; i < cats.length; i++) {
        if (cats[i].textContent.trim() === '短文') { isShort = true; break; }
      }
      if (!isShort) {
        var ts = c.querySelectorAll('.article-meta__tags a');
        for (var j = 0; j < ts.length; j++) {
          if (ts[j].textContent.trim() === '朋友圈') { isShort = true; break; }
        }
      }
      if (isShort) c.classList.add('moment-style');
    });
  }

  // 文章页：阅读进度 + 阅读时间 + 评论
  if (isPost) {
    var pb = document.createElement('div');
    pb.id = 'reading-progress';
    document.body.prepend(pb);
    window.addEventListener('scroll', function () {
      var t = document.documentElement.scrollTop || document.body.scrollTop;
      var h = document.documentElement.scrollHeight - document.documentElement.clientHeight;
      pb.style.width = h > 0 ? (t / h * 100) + '%' : '0';
    });

    var pc = document.querySelector('.post-content');
    if (pc) {
      var txt = pc.textContent.replace(/\s+/g, '');
      var len = txt.length;
      var min = Math.max(1, Math.round(len / 400));
      var rt = document.createElement('div');
      rt.className = 'reading-time';
      rt.textContent = '阅读时间约 ' + min + ' 分钟 · ' + len + ' 字';
      var pi = document.getElementById('post-info');
      if (pi) { pi.appendChild(rt); }
      else { pc.parentNode.insertBefore(rt, pc); }

      var fn = document.createElement('div');
      fn.className = 'post-footer-nav';
      fn.innerHTML = '<a href="/">Back to home</a>';
      pc.appendChild(fn);

      var articleTitle = document.title.split(' | ')[0];
      var cb = document.createElement('div');
      cb.className = 'comment-btn-wrap';
      cb.appendChild(createMailButton({
        className: 'comment-btn',
        label: '写评论',
        icon: '📧',
        subject: '[评论] ' + articleTitle,
        body: [
          '请不要修改邮件模板内容，只填写“用户名”和“评论内容”即可。',
          '',
          '文章：' + articleTitle,
          '用户名：',
          '评论内容：'
        ].join('\n')
      }));
      pc.appendChild(cb);

      loadComments(articleTitle);
    }
  }

  function createMailButton(options) {
    var link = document.createElement('a');
    link.className = options.className;
    link.href = buildMailto(options.subject, options.body);

    var icon = document.createElement('span');
    icon.className = 'comment-btn-icon';
    icon.setAttribute('aria-hidden', 'true');
    icon.textContent = options.icon;

    var label = document.createElement('span');
    label.className = 'comment-btn-label';
    label.textContent = options.label;

    link.appendChild(icon);
    link.appendChild(label);
    return link;
  }

  function buildMailto(subject, body) {
    return 'mailto:' + COMMENT_EMAIL +
      '?subject=' + encodeURIComponent(subject) +
      '&body=' + encodeURIComponent(body).replace(/%0A/g, '%0D%0A');
  }

  function loadComments(article) {
    fetch('/data/comments.json', { cache: 'no-store' })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var key = Object.keys(data).find(function (k) { return k === article || k === decodeURIComponent(article); });
        if (!key && data[article]) key = article;
        if (!key || !data[key] || data[key].length === 0) return;

        var cd = document.createElement('div');
        cd.className = 'comments-display';

        var heading = document.createElement('h3');
        heading.textContent = '💬 评论 (' + data[key].length + ')';
        cd.appendChild(heading);

        data[key].slice().sort(sortByTime).forEach(function (c) {
          cd.appendChild(renderComment(article, c));
        });

        var pc3 = document.querySelector('.post-content');
        if (pc3) pc3.appendChild(cd);
      })
      .catch(function () {});
  }

  function renderComment(article, c) {
    var item = document.createElement('div');
    item.className = 'comment-item';

    item.appendChild(renderCommentHeader(c));

    var text = document.createElement('div');
    text.className = 'comment-text';
    text.textContent = c.content || '';
    item.appendChild(text);

    var actions = document.createElement('div');
    actions.className = 'comment-actions';
    actions.appendChild(createMailButton({
      className: 'comment-reply-btn',
      label: '回复',
      icon: '↩',
      subject: '[回复] ' + article,
      body: [
        '请不要修改邮件模板内容，只填写“用户名”和“回复内容”即可。',
        '',
        '文章：' + article,
        '回复给：' + (c.user || '匿名'),
        '回复ID：' + (c.id || ''),
        '用户名：',
        '回复内容：'
      ].join('\n')
    }));
    item.appendChild(actions);

    var replies = (c.replies || []).slice().sort(sortByTime);
    if (replies.length > 0) {
      var repliesWrap = document.createElement('div');
      repliesWrap.className = 'comment-replies';
      replies.forEach(function (reply) {
        repliesWrap.appendChild(renderReply(reply));
      });
      item.appendChild(repliesWrap);
    }

    return item;
  }

  function renderReply(reply) {
    var item = document.createElement('div');
    item.className = 'comment-reply';

    item.appendChild(renderCommentHeader(reply));

    var text = document.createElement('div');
    text.className = 'comment-text';
    text.textContent = reply.content || '';
    item.appendChild(text);

    return item;
  }

  function renderCommentHeader(c) {
    var user = document.createElement('div');
    user.className = 'comment-user';
    user.appendChild(document.createTextNode(c.user || '匿名'));

    var date = document.createElement('span');
    date.className = 'comment-date';
    date.textContent = c.date || formatDate(c.timestamp) || '';
    user.appendChild(date);

    return user;
  }

  function sortByTime(a, b) {
    return String(a.timestamp || a.date || '').localeCompare(String(b.timestamp || b.date || ''));
  }

  function formatDate(value) {
    if (!value) return '';
    var date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;
    var pad = function (n) { return String(n).padStart(2, '0'); };
    return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate()) + ' ' + pad(date.getHours()) + ':' + pad(date.getMinutes());
  }
});
