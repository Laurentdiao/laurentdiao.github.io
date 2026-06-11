// custom.js - 评论按钮 + 朋友圈样式 + 阅读进度 + 你好标题
document.addEventListener('DOMContentLoaded', function () {
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
        for (var i = 0; i < ts.length; i++) {
          if (ts[i].textContent.trim() === '朋友圈') { isShort = true; break; }
        }
      }
      if (isShort) c.classList.add('moment-style');
    });
  }

  // 文章页：阅读进度 + 阅读时间 + 评论
  if (isPost) {
    // 阅读进度条
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
      // 阅读时间
      var txt = pc.textContent.replace(/\s+/g, '');
      var len = txt.length;
      var min = Math.max(1, Math.round(len / 400));
      var rt = document.createElement('div');
      rt.className = 'reading-time';
      rt.textContent = '阅读时间约 ' + min + ' 分钟 · ' + len + ' 字';
      var pi = document.getElementById('post-info');
      if (pi) { pi.appendChild(rt); }
      else { pc.parentNode.insertBefore(rt, pc); }

      // 返回首页
      var fn = document.createElement('div');
      fn.className = 'post-footer-nav';
      fn.innerHTML = '<a href="/">Back to home</a>';
      pc.appendChild(fn);

      // 评论按钮
      var t2 = document.title.split(' | ')[0];
      var cb = document.createElement('div');
      cb.className = 'comment-btn-wrap';
      cb.innerHTML = '<a class="comment-btn" href="mailto:gergptdd@hotmail.com?subject=%5B%E8%AF%84%E8%AE%BA%5D%20' 
        + encodeURIComponent(t2) 
        + '&body=%E7%94%A8%E6%88%B7%E5%90%8D%EF%BC%9A%0A%E8%AF%84%E8%AE%BA%E5%86%85%E5%AE%B9%EF%BC%9A%0A"><span class="comment-btn-icon" aria-hidden="true">📧</span><span class="comment-btn-label">写评论</span></a>';
      pc.appendChild(cb);

      // 加载已有评论
      loadComments(t2);
    }
  }

  // 加载评论数据
  function loadComments(article) {
    fetch('/data/comments.json')
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var key = Object.keys(data).find(function (k) { return k === article || k === decodeURIComponent(article); });
        if (!key && data[article]) key = article;
        if (key && data[key] && data[key].length > 0) {
          var cd = document.createElement('div');
          cd.className = 'comments-display';

          var heading = document.createElement('h3');
          heading.textContent = '💬 评论 (' + data[key].length + ')';
          cd.appendChild(heading);

          data[key].forEach(function (c) {
            var item = document.createElement('div');
            item.className = 'comment-item';

            var user = document.createElement('div');
            user.className = 'comment-user';
            user.appendChild(document.createTextNode(c.user || '匿名'));

            var date = document.createElement('span');
            date.className = 'comment-date';
            date.textContent = c.date || '';
            user.appendChild(date);

            var text = document.createElement('div');
            text.className = 'comment-text';
            text.textContent = c.content || '';

            item.appendChild(user);
            item.appendChild(text);
            cd.appendChild(item);
          });
          var pc3 = document.querySelector('.post-content');
          if (pc3) pc3.appendChild(cd);
        }
      })
      .catch(function () {});
  }
});
