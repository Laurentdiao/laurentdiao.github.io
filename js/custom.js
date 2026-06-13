// custom.js - 评论按钮 + 朋友圈样式 + 阅读进度 + 你好标题
document.addEventListener('DOMContentLoaded', function () {
  var COMMENT_EMAIL = 'dwinnie137@gmail.com';
  var SUBSCRIBE_EMAIL = 'dwinnie137@gmail.com';
  var SUBSCRIBE_STORAGE_KEY = 'winnie_blog_subscribe_email';
  var isPost = !!document.getElementById('article-container');
  var isHome = !!document.getElementById('recent-posts');

  injectSubscribeButton();
  bindMenuSubscribeInjection();

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
        iconClass: 'far fa-envelope',
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
    if (options.iconClass) {
      var iconGlyph = document.createElement('i');
      iconGlyph.className = options.iconClass;
      icon.appendChild(iconGlyph);
    } else {
      icon.textContent = options.icon || '';
    }

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

  function injectSubscribeButton() {
    document.querySelectorAll('.menus_items').forEach(function (menus) {
      if (menus.querySelector('.subscribe-nav-item')) return;
      var item = document.createElement('div');
      item.className = 'menus_item subscribe-nav-item';
      var button = document.createElement('button');
      button.type = 'button';
      button.className = 'site-page subscribe-nav-btn';
      button.textContent = '订阅';
      item.appendChild(button);
      menus.appendChild(item);
      button.addEventListener('click', openSubscribeDialog);
    });
  }

  function bindMenuSubscribeInjection() {
    var toggle = document.getElementById('toggle-menu');
    if (!toggle) return;
    toggle.addEventListener('click', function () {
      window.setTimeout(injectSubscribeButton, 0);
    });
  }

  function openSubscribeDialog() {
    closeSubscribeDialog();

    var overlay = document.createElement('div');
    overlay.className = 'subscribe-modal';
    overlay.id = 'subscribe-modal';
    overlay.innerHTML = [
      '<div class="subscribe-panel" role="dialog" aria-modal="true" aria-labelledby="subscribe-title">',
      '<button class="subscribe-close" type="button" aria-label="关闭">×</button>',
      '<p class="subscribe-eyebrow">Email Updates</p>',
      '<h2 id="subscribe-title">订阅新文章</h2>',
      '<p class="subscribe-copy">填写邮箱并选择想收到的文章类型。点击订阅后会打开邮件 App，请直接发送生成好的邮件。</p>',
      '<label class="subscribe-label" for="subscribe-email">邮箱</label>',
      '<input id="subscribe-email" class="subscribe-input" type="email" inputmode="email" autocomplete="email" placeholder="you@example.com">',
      '<div class="subscribe-label">文章类型</div>',
      '<div class="subscribe-options">',
      '<label><input type="radio" name="subscribe-type" value="长文"><span>长文</span></label>',
      '<label><input type="radio" name="subscribe-type" value="短文"><span>短文</span></label>',
      '<label><input type="radio" name="subscribe-type" value="both" checked><span>Both</span></label>',
      '</div>',
      '<p id="subscribe-error" class="subscribe-error" hidden></p>',
      '<button id="subscribe-submit" class="subscribe-submit" type="button">订阅</button>',
      '<p class="subscribe-note">邮箱不会公开显示在网站或 GitHub 代码中。</p>',
      '</div>'
    ].join('');

    document.body.appendChild(overlay);
    var input = document.getElementById('subscribe-email');
    input.value = localStorage.getItem(SUBSCRIBE_STORAGE_KEY) || '';
    input.focus();

    overlay.addEventListener('click', function (event) {
      if (event.target === overlay) closeSubscribeDialog();
    });
    overlay.querySelector('.subscribe-close').addEventListener('click', closeSubscribeDialog);
    overlay.querySelector('#subscribe-submit').addEventListener('click', submitSubscribe);
    document.addEventListener('keydown', closeSubscribeOnEscape);
  }

  function closeSubscribeDialog() {
    var modal = document.getElementById('subscribe-modal');
    if (modal) modal.remove();
    document.removeEventListener('keydown', closeSubscribeOnEscape);
  }

  function closeSubscribeOnEscape(event) {
    if (event.key === 'Escape') closeSubscribeDialog();
  }

  function submitSubscribe() {
    var emailInput = document.getElementById('subscribe-email');
    var error = document.getElementById('subscribe-error');
    var selected = document.querySelector('input[name="subscribe-type"]:checked');
    var subscriberEmail = (emailInput.value || '').trim();
    var type = selected ? selected.value : 'both';

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(subscriberEmail)) {
      error.textContent = '请填写有效邮箱。';
      error.hidden = false;
      emailInput.focus();
      return;
    }

    localStorage.setItem(SUBSCRIBE_STORAGE_KEY, subscriberEmail);
    window.location.href = buildSubscribeMailto(subscriberEmail, type);
    closeSubscribeDialog();
  }

  function buildSubscribeMailto(email, type) {
    var label = type === 'both' ? 'both' : type;
    var body = [
      '请不要修改邮件模板内容。',
      '',
      '订阅邮箱：' + email,
      '文章类型：' + label
    ].join('\n');
    return 'mailto:' + SUBSCRIBE_EMAIL +
      '?subject=' + encodeURIComponent('[订阅] Winnies Blog') +
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
        heading.textContent = '评论 (' + data[key].length + ')';
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
      iconClass: 'fas fa-reply',
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
