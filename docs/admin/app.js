(() => {
  const owner = 'Laurentdiao';
  const repo = 'laurentdiao.github.io';
  const branch = 'main';
  const apiBase = `https://api.github.com/repos/${owner}/${repo}/contents`;
  const tokenKey = 'winnie_blog_admin_token';
  const tags = ['随笔', '技术', '生活', '读书笔记', '朋友圈', '日常', '其他'];
  const requestTimeoutMs = 15000;

  const state = {
    token: localStorage.getItem(tokenKey) || '',
    posts: [],
    selectedPost: null,
    about: null,
    currentView: 'posts'
  };

  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => Array.from(document.querySelectorAll(selector));

  const elements = {
    viewTitle: $('#view-title'),
    notice: $('#notice'),
    busy: $('#busy'),
    syncLabel: $('#sync-label'),
    setupView: $('#setup-view'),
    postsView: $('#posts-view'),
    aboutView: $('#about-view'),
    settingsView: $('#settings-view'),
    postsList: $('#posts-list'),
    postCount: $('#post-count'),
    postForm: $('#post-form'),
    postMode: $('#post-mode'),
    postOriginalFilename: $('#post-original-filename'),
    postSha: $('#post-sha'),
    postEditorTitle: $('#post-editor-title'),
    postTitle: $('#post-title-input'),
    postContent: $('#post-content-input'),
    deletePost: $('#delete-post-btn'),
    savePost: $('#save-post-btn'),
    tagsGrid: $('#tags-grid'),
    imageInput: $('#image-input'),
    aboutForm: $('#about-form'),
    aboutSha: $('#about-sha'),
    aboutTitle: $('#about-title-input'),
    aboutContent: $('#about-content-input'),
    setupToken: $('#setup-token'),
    settingsToken: $('#settings-token')
  };

  document.addEventListener('DOMContentLoaded', init);

  function init() {
    renderTags();
    bindEvents();
    renderTokenState();
    setView(state.token ? 'posts' : 'settings');
    const params = new URLSearchParams(window.location.search);
    if (state.token && !params.has('nosync')) {
      syncAll();
    }
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/admin/sw.js?v=20260612b').catch(() => {});
    }
  }

  function bindEvents() {
    $$('.nav-btn').forEach((button) => {
      button.addEventListener('click', () => setView(button.dataset.view));
    });

    $('#refresh-btn').addEventListener('click', syncAll);
    $('#new-post-btn').addEventListener('click', startNewPost);
    $('#mobile-new-post-btn').addEventListener('click', startNewPost);
    $('#reset-post-btn').addEventListener('click', startNewPost);
    $('#open-site-btn').addEventListener('click', () => window.open('https://laurentdiao.github.io', '_blank', 'noreferrer'));
    $('#image-btn').addEventListener('click', () => elements.imageInput.click());
    elements.imageInput.addEventListener('change', handleImageSelection);
    elements.postForm.addEventListener('submit', savePost);
    elements.deletePost.addEventListener('click', deleteSelectedPost);
    elements.aboutForm.addEventListener('submit', saveAbout);
    $('#setup-save-btn').addEventListener('click', () => saveToken(elements.setupToken.value));
    $('#settings-save-btn').addEventListener('click', () => saveToken(elements.settingsToken.value));
    $('#settings-clear-btn').addEventListener('click', clearToken);
  }

  function renderTags() {
    elements.tagsGrid.innerHTML = tags.map((tag) => `
      <label class="tag-chip">
        <input type="checkbox" name="tag" value="${escapeAttr(tag)}">
        <span>${escapeHtml(tag)}</span>
      </label>
    `).join('');
  }

  function renderTokenState() {
    elements.setupToken.value = state.token;
    elements.settingsToken.value = state.token;
    if (!state.token) {
      elements.syncLabel.textContent = '未连接 GitHub';
    }
  }

  function setView(view) {
    state.currentView = view;
    $$('.nav-btn').forEach((button) => button.classList.toggle('is-active', button.dataset.view === view));

    const configured = Boolean(state.token);
    elements.setupView.hidden = configured;
    elements.postsView.hidden = !configured || view !== 'posts';
    elements.aboutView.hidden = !configured || view !== 'about';
    elements.settingsView.hidden = !configured || view !== 'settings';
    $('#refresh-btn').disabled = !configured;
    $('#new-post-btn').disabled = !configured;
    $('#mobile-new-post-btn').disabled = !configured;

    const titles = { posts: '文章', about: 'About Me', settings: '设置' };
    elements.viewTitle.textContent = configured ? titles[view] : '设置';

    if (configured && view === 'about' && !state.about) {
      loadAbout();
    }
  }

  async function syncAll() {
    if (!requireToken()) return;
    await withBusy(async () => {
      await Promise.all([loadPosts(), loadAbout()]);
      elements.syncLabel.textContent = `已同步 ${formatTime(new Date())}`;
      showNotice('同步完成。', false);
    });
  }

  async function loadPosts() {
    const files = await githubJSON('source/_posts');
    const markdownFiles = files.filter((file) => file.name.endsWith('.md'));
    const posts = [];

    for (const file of markdownFiles) {
      const full = await githubJSON(file.path);
      const markdown = decodeBase64Text(full.content || '');
      const parsed = parseMarkdown(markdown);
      if (!parsed.frontMatter.title) continue;
      posts.push({
        title: parsed.frontMatter.title,
        date: parsed.frontMatter.date || '',
        tags: listValue(parsed, 'tags'),
        categories: listValue(parsed, 'categories'),
        content: parsed.body,
        filename: file.name,
        path: file.path,
        sha: full.sha
      });
    }

    state.posts = posts.sort((a, b) => String(b.date).localeCompare(String(a.date)));
    renderPosts();
    if (!state.selectedPost) startNewPost();
  }

  async function loadAbout() {
    const file = await githubJSON('source/about/index.md');
    const parsed = parseMarkdown(decodeBase64Text(file.content || ''));
    state.about = {
      title: parsed.frontMatter.title || '关于',
      date: parsed.frontMatter.date || blogTimestamp(),
      type: parsed.frontMatter.type || 'about',
      content: parsed.body,
      sha: file.sha
    };
    renderAbout();
  }

  function renderPosts() {
    elements.postCount.textContent = `${state.posts.length} 篇`;
    if (state.posts.length === 0) {
      elements.postsList.innerHTML = '<div class="post-item"><h4>还没有文章</h4><p class="post-excerpt">从右侧开始写第一篇。</p></div>';
      return;
    }

    elements.postsList.innerHTML = state.posts.map((post) => `
      <button class="post-item ${state.selectedPost?.filename === post.filename ? 'is-selected' : ''}" type="button" data-filename="${escapeAttr(post.filename)}">
        <h4>${escapeHtml(post.title)}</h4>
        <div class="post-meta">
          <span>${escapeHtml(String(post.date).slice(0, 10) || '无日期')}</span>
          ${post.categories.slice(0, 1).map((item) => `<span class="pill">${escapeHtml(item)}</span>`).join('')}
          ${post.tags.slice(0, 2).map((item) => `<span class="pill">${escapeHtml(item)}</span>`).join('')}
        </div>
        <p class="post-excerpt">${escapeHtml(excerpt(post.content))}</p>
      </button>
    `).join('');

    $$('.post-item[data-filename]').forEach((button) => {
      button.addEventListener('click', () => {
        const post = state.posts.find((item) => item.filename === button.dataset.filename);
        if (post) editPost(post);
      });
    });
  }

  function startNewPost() {
    state.selectedPost = null;
    elements.postMode.value = 'create';
    elements.postOriginalFilename.value = '';
    elements.postSha.value = '';
    elements.postEditorTitle.textContent = '写文章';
    elements.savePost.textContent = '发布';
    elements.deletePost.hidden = true;
    elements.postTitle.value = '';
    elements.postContent.value = '';
    setCategory('长文');
    setSelectedTags(['随笔']);
    renderPosts();
    setView('posts');
  }

  function editPost(post) {
    state.selectedPost = post;
    elements.postMode.value = 'edit';
    elements.postOriginalFilename.value = post.filename;
    elements.postSha.value = post.sha;
    elements.postEditorTitle.textContent = '编辑文章';
    elements.savePost.textContent = '保存';
    elements.deletePost.hidden = false;
    elements.postTitle.value = post.title;
    elements.postContent.value = post.content;
    setCategory(post.categories[0] || '长文');
    setSelectedTags(post.tags.length ? post.tags : ['随笔']);
    renderPosts();
    setView('posts');
  }

  function renderAbout() {
    if (!state.about) return;
    elements.aboutSha.value = state.about.sha;
    elements.aboutTitle.value = state.about.title;
    elements.aboutContent.value = state.about.content;
  }

  async function savePost(event) {
    event.preventDefault();
    if (!requireToken()) return;

    const title = elements.postTitle.value.trim();
    const content = elements.postContent.value.trim();
    if (!title || !content) {
      showNotice('标题和正文都要填写。', true);
      return;
    }

    const selectedTags = getSelectedTags();
    const category = getSelectedCategory();
    const filename = `${sanitizeFilename(title)}.md`;
    const path = `source/_posts/${filename}`;
    const markdown = postMarkdown({
      title,
      date: state.selectedPost?.date || blogTimestamp(),
      tags: selectedTags.length ? selectedTags : ['随笔'],
      categories: [category],
      content
    });

    await withBusy(async () => {
      const mode = elements.postMode.value;
      if (mode === 'edit' && elements.postOriginalFilename.value && filename !== elements.postOriginalFilename.value) {
        await putFile(path, markdown, null, `Update ${title}`);
        await deleteFile(`source/_posts/${elements.postOriginalFilename.value}`, elements.postSha.value, `Rename ${state.selectedPost?.title || title}`);
      } else {
        await putFile(path, markdown, mode === 'edit' ? elements.postSha.value : null, mode === 'edit' ? `Update ${title}` : `Add ${title}`);
      }

      showNotice('已提交到 GitHub，等待 Actions 更新网页。', false);
      await loadPosts();
      const saved = state.posts.find((post) => post.filename === filename);
      if (saved) editPost(saved);
    });
  }

  async function deleteSelectedPost() {
    if (!state.selectedPost) return;
    const ok = window.confirm(`删除「${state.selectedPost.title}」？这个操作会直接提交到 GitHub。`);
    if (!ok) return;

    await withBusy(async () => {
      await deleteFile(`source/_posts/${state.selectedPost.filename}`, state.selectedPost.sha, `Delete ${state.selectedPost.title}`);
      showNotice('文章已删除。', false);
      state.selectedPost = null;
      await loadPosts();
      startNewPost();
    });
  }

  async function saveAbout(event) {
    event.preventDefault();
    if (!requireToken() || !state.about) return;

    const title = elements.aboutTitle.value.trim();
    const content = elements.aboutContent.value.trim();
    if (!title || !content) {
      showNotice('About Me 标题和内容都要填写。', true);
      return;
    }

    const markdown = [
      '---',
      `title: ${title}`,
      `date: ${state.about.date || blogTimestamp()}`,
      `type: ${state.about.type || 'about'}`,
      '---',
      '',
      content,
      ''
    ].join('\n');

    await withBusy(async () => {
      await putFile('source/about/index.md', markdown, state.about.sha, 'Update About Me');
      showNotice('About Me 已提交。', false);
      await loadAbout();
    });
  }

  async function handleImageSelection(event) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    if (!requireToken()) return;

    await withBusy(async () => {
      const extension = imageExtension(file);
      const path = `source/images/admin_${Date.now()}_${randomSuffix()}.${extension}`;
      const buffer = await file.arrayBuffer();
      await putFileBase64(path, base64FromArrayBuffer(buffer), null, 'Upload image');
      insertAtCursor(elements.postContent, `\n\n![](/images/${path.split('/').pop()})\n`);
      showNotice('图片已上传并插入正文。', false);
    });
  }

  function saveToken(rawToken) {
    const token = rawToken.trim();
    if (!token) {
      showNotice('请先粘贴 GitHub token。', true);
      return;
    }
    state.token = token;
    localStorage.setItem(tokenKey, token);
    renderTokenState();
    setView('posts');
    syncAll();
  }

  function clearToken() {
    state.token = '';
    localStorage.removeItem(tokenKey);
    state.posts = [];
    state.selectedPost = null;
    state.about = null;
    renderTokenState();
    setView('settings');
    showNotice('Token 已清除。', false);
  }

  async function putFile(path, text, sha, message) {
    return putFileBase64(path, base64FromText(text), sha, message);
  }

  async function putFileBase64(path, content, sha, message) {
    const body = { message, content, branch };
    if (sha) body.sha = sha;
    return githubJSON(path, { method: 'PUT', body });
  }

  async function deleteFile(path, sha, message) {
    return githubJSON(path, { method: 'DELETE', body: { message, sha, branch } });
  }

  async function githubJSON(path, options = {}) {
    const method = options.method || 'GET';
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), requestTimeoutMs);
    const requestOptions = {
      method,
      signal: controller.signal,
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${state.token}`,
        'X-GitHub-Api-Version': '2022-11-28'
      }
    };

    if (options.body) {
      requestOptions.headers['Content-Type'] = 'application/json';
      requestOptions.body = JSON.stringify(options.body);
    }

    try {
      const response = await fetch(`${apiBase}/${encodePath(path)}`, requestOptions);
      if (!response.ok) {
        let detail = response.statusText;
        try {
          const data = await response.json();
          detail = data.message || detail;
        } catch (_) {}
        if (response.status === 409) {
          detail = '远端刚刚更新，请刷新后重试。';
        }
        if (response.status === 401 || response.status === 403) {
          detail = `${detail}。请检查 token 是否仍有效，并确认 Contents 权限是 Read and write。`;
        }
        throw new Error(`GitHub 返回 ${response.status}: ${detail}`);
      }
      if (response.status === 204) return {};
      return response.json();
    } catch (error) {
      if (error.name === 'AbortError') {
        throw new Error('GitHub API 请求超时。请检查网络或 token，稍后点刷新重试。');
      }
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  }

  function requireToken() {
    if (state.token) return true;
    setView('settings');
    showNotice('请先保存 GitHub token。', true);
    return false;
  }

  async function withBusy(task) {
    elements.busy.hidden = false;
    clearNotice();
    try {
      await task();
    } catch (error) {
      showNotice(error.message || String(error), true);
    } finally {
      elements.busy.hidden = true;
    }
  }

  function showNotice(message, isError) {
    elements.notice.textContent = message;
    elements.notice.classList.toggle('is-error', Boolean(isError));
    elements.notice.hidden = false;
  }

  function clearNotice() {
    elements.notice.hidden = true;
    elements.notice.textContent = '';
  }

  function parseMarkdown(markdown) {
    const normalized = markdown.replace(/\r\n/g, '\n');
    if (!normalized.startsWith('---\n')) {
      return { frontMatter: {}, lists: {}, body: markdown.trim() };
    }

    const end = normalized.indexOf('\n---', 4);
    if (end === -1) {
      return { frontMatter: {}, lists: {}, body: markdown.trim() };
    }

    const front = normalized.slice(4, end);
    let bodyStart = end + 4;
    if (normalized[bodyStart] === '\n') bodyStart += 1;
    const body = normalized.slice(bodyStart).trim();
    const frontMatter = {};
    const lists = {};
    let activeKey = null;

    front.split('\n').forEach((line) => {
      const trimmed = line.trim();
      if (trimmed.startsWith('- ') && activeKey) {
        const value = trimmed.slice(2).trim();
        if (value) lists[activeKey].push(stripQuotes(value));
        return;
      }
      activeKey = null;
      const colon = trimmed.indexOf(':');
      if (colon === -1) return;
      const key = trimmed.slice(0, colon).trim();
      const value = trimmed.slice(colon + 1).trim();
      if (!value) {
        lists[key] = [];
        activeKey = key;
      } else {
        frontMatter[key] = stripQuotes(value);
      }
    });

    return { frontMatter, lists, body };
  }

  function postMarkdown(post) {
    const lines = ['---', `title: ${post.title}`, `date: ${post.date || blogTimestamp()}`];
    if (post.tags?.length) {
      lines.push('tags:');
      post.tags.forEach((tag) => lines.push(`  - ${tag}`));
    }
    if (post.categories?.length) {
      lines.push('categories:');
      post.categories.forEach((category) => lines.push(`  - ${category}`));
    }
    lines.push('---', '', post.content.trim(), '');
    return lines.join('\n');
  }

  function listValue(parsed, key) {
    if (parsed.lists[key]) return parsed.lists[key];
    if (parsed.frontMatter[key]) return [parsed.frontMatter[key]];
    return [];
  }

  function setCategory(category) {
    $$('input[name="category"]').forEach((input) => {
      input.checked = input.value === category;
    });
  }

  function getSelectedCategory() {
    return $('input[name="category"]:checked')?.value || '长文';
  }

  function setSelectedTags(selected) {
    $$('input[name="tag"]').forEach((input) => {
      input.checked = selected.includes(input.value);
    });
  }

  function getSelectedTags() {
    return $$('input[name="tag"]:checked').map((input) => input.value);
  }

  function insertAtCursor(textarea, text) {
    const start = textarea.selectionStart ?? textarea.value.length;
    const end = textarea.selectionEnd ?? textarea.value.length;
    textarea.value = `${textarea.value.slice(0, start)}${text}${textarea.value.slice(end)}`;
    textarea.focus();
    textarea.selectionStart = textarea.selectionEnd = start + text.length;
  }

  function encodePath(path) {
    return path.split('/').map((part) => encodeURIComponent(part)).join('/');
  }

  function base64FromText(text) {
    return base64FromArrayBuffer(new TextEncoder().encode(text).buffer);
  }

  function base64FromArrayBuffer(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    const chunk = 0x8000;
    for (let i = 0; i < bytes.length; i += chunk) {
      binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
    }
    return btoa(binary);
  }

  function decodeBase64Text(value) {
    const binary = atob(String(value).replace(/\n/g, ''));
    const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
    return new TextDecoder().decode(bytes);
  }

  function sanitizeFilename(value) {
    const cleaned = value.replace(/[\\/:*?"<>|]/g, '_').trim();
    return cleaned || `untitled-${Date.now()}`;
  }

  function blogTimestamp() {
    const date = new Date();
    const pad = (number) => String(number).padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
  }

  function imageExtension(file) {
    const fromName = file.name.split('.').pop()?.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(fromName)) return fromName;
    const fromType = file.type.split('/').pop()?.toLowerCase();
    if (fromType === 'jpeg') return 'jpg';
    if (['png', 'gif', 'webp'].includes(fromType)) return fromType;
    return 'jpg';
  }

  function randomSuffix() {
    return Math.random().toString(36).slice(2, 8);
  }

  function stripQuotes(value) {
    return value.replace(/^['"]|['"]$/g, '');
  }

  function excerpt(value) {
    return String(value || '').replace(/\s+/g, ' ').trim().slice(0, 88) || '无正文预览';
  }

  function formatTime(date) {
    return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
  }

  function escapeHtml(value) {
    return String(value).replace(/[&<>"']/g, (char) => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;'
    }[char]));
  }

  function escapeAttr(value) {
    return escapeHtml(value);
  }
})();
